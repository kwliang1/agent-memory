require 'prism'

NOISE = %w[
  T T::Boolean T::Array T::Hash T::Struct T::Enum T::Set
  Integer String Float Symbol Hash Array Set Range Proc Numeric Rational
  NilClass TrueClass FalseClass Object BasicObject Module Class Comparable Enumerable Kernel
  Time Date DateTime ActiveSupport::TimeWithZone BigDecimal
  Exception StandardError ArgumentError RuntimeError TypeError KeyError NameError
  NotImplementedError FrozenError IndexError StopIteration ZeroDivisionError
  JSON YAML URI Logger Mutex Thread File Dir IO Kernel Math Struct OpenStruct
  Boolean Numeric Data
].to_set

def read_source(path) = File.read(path, encoding: "UTF-8").scrub

nodes = {}   # fqn -> [file, line]
edges = []   # [src_fqn, dst_const]

ARGV.each do |path|
  src = read_source(path) rescue next
  res = Prism.parse(src) rescue next

  walk = ->(node, stack) do
    return unless node.is_a?(Prism::Node)
    case node
    when Prism::ClassNode, Prism::ModuleNode
      name = node.constant_path.slice
      fqn  = (stack + [name]).join("::")
      # lowest (path, line) wins, not first-encountered: a constant reopened across
      # files would otherwise record a citation that depends on git ls-files order
      cand = [path, node.location.start_line]
      cur  = nodes[fqn]
      nodes[fqn] = cand if cur.nil? || (cand <=> cur) == -1
      node.compact_child_nodes.each { |c| walk.(c, stack + [name]) }
      return
    when Prism::ConstantReadNode, Prism::ConstantPathNode
      unless stack.empty?
        t = node.slice
        edges << [stack.join("::"), t, stack.dup] unless NOISE.include?(t) || t.length < 3
      end
      return
    end
    node.compact_child_nodes.each { |c| walk.(c, stack) }
  end
  walk.(res.value, [])
end

# keep only edges whose target resolves to a node we actually defined.
# resolution order: exact -> nearest enclosing lexical scope -> unique suffix.
# an ambiguous bare name is DROPPED, never guessed: guessing invented a
# 190-in-degree hub by gluing every `TreasuryPrime` reference (a gem, not in
# this tree) onto an unrelated oncall adapter.
defined = nodes.keys.to_set
suffix = Hash.new { |h, k| h[k] = [] }
defined.each { |n| suffix[n.split("::").last] << n }

ambiguous = 0
dropped   = 0
resolved = edges.filter_map do |src, d, stack|
  hit =
    if defined.include?(d)
      d
    else
      scoped = nil
      stack.length.downto(1) do |i|
        cand = (stack[0, i] + [d]).join("::")
        if defined.include?(cand)
          scoped = cand
          break
        end
      end
      if scoped
        scoped
      else
        cands = suffix[d.split("::").last].select { |n| n == d || n.end_with?("::#{d}") }
        if cands.size == 1
          cands.first
        else
          ambiguous += 1 if cands.size > 1
          dropped += 1 if cands.empty?
          nil
        end
      end
    end
  hit && hit != src ? [src, hit] : nil
end.uniq

out = Hash.new(0); resolved.each { |s, _| out[s] += 1 }
inn = Hash.new(0); resolved.each { |_, d| inn[d] += 1 }

puts "nodes (class/module):  #{nodes.size}"
puts "dropped: #{ambiguous} ambiguous, #{dropped} unresolvable (not guessed)"
puts "edges (resolved refs): #{resolved.size}"
puts
deg = out.values.sort
puts "OUT-DEGREE  median #{deg[deg.size/2]}  mean #{'%.1f' % (deg.sum.to_f/deg.size)}  p90 #{deg[(deg.size*0.9).to_i]}  p99 #{deg[(deg.size*0.99).to_i]}  max #{deg.last}"
ind = inn.values.sort
puts "IN-DEGREE   median #{ind[ind.size/2]}  mean #{'%.1f' % (ind.sum.to_f/ind.size)}  p90 #{ind[(ind.size*0.9).to_i]}  p99 #{ind[(ind.size*0.99).to_i]}  max #{ind.last}"
puts
puts "TOP HUBS by in-degree (the nodes that break naive traversal):"
# k breaks ties: without it rank 12 flipped with input file order
inn.sort_by { |k, v| [-v, k] }.first(12).each { |n, v| puts "  #{v.to_s.rjust(5)}  #{n}" }


# ---- schema edges -------------------------------------------------------------
# The AST sees constant references. A relation carried by a COLUMN is invisible to
# it: CustomerAccount and five other models share `owner_entity_api_id`, which is how
# they reach entity verification, and none of that is a constant anywhere. Same class
# as the cross-repo gap — real in the domain, no syntactic trace as a reference.
#
# Two shapes, both cheap:
#   fk            column `customer_account_id` on model X -> constant CustomerAccount
#   shares_column two models carrying the same non-resolving column (owner_entity_api_id)
# plus belongs_to/has_many/has_one, which ARE in the AST; I just was not reading them.

def camelize(s) = s.split('_').map { |p| p[0].to_s.upcase + p[1..].to_s }.join

schema_edges = []
cols = Hash.new { |h, k| h[k] = [] }   # column -> [model, ...]

ARGV.each do |path|
  src = read_source(path) rescue next
  # the class this file declares, by the same lexical rule the main walk uses
  res = Prism.parse(src) rescue next
  owner = nil
  find = ->(node, stack) do
    return if owner || !node.is_a?(Prism::Node)
    if node.is_a?(Prism::ClassNode)
      owner = (stack + [node.constant_path.slice]).join("::")
      return
    end
    node.compact_child_nodes.each { |c| find.(c, node.is_a?(Prism::ModuleNode) ? stack + [node.constant_path.slice] : stack) }
  end
  find.(res.value, [])
  next unless owner

  # annotation columns
  src.each_line do |l|
    next unless l =~ /\A#\s{2}([a-z_]+)\s+:/
    col = $1
    next unless col.end_with?("_id")
    cols[col] << owner
    schema_edges << [owner, camelize(col.sub(/_id\z/, "")), "fk"]
  end

  # associations, including class_name: overrides
  src.each_line do |l|
    next unless l =~ /\A\s*(belongs_to|has_many|has_one)\s+:([a-z_]+)(.*)/
    kind, name, rest = $1, $2, $3
    target = rest[/class_name:\s*['"]([A-Za-z0-9_:]+)['"]/, 1]
    target ||= kind == "has_many" ? camelize(name).sub(/s\z/, "") : camelize(name)
    schema_edges << [owner, target, "assoc"]
  end
end

# two models sharing a column that resolves to nothing still share a relation
# A name SYNTHESIZED from a column is not evidence the way a constant a human wrote is.
# `fk` and `assoc` targets must match exactly: a unique-suffix guess turned a company_id
# column into an edge to Mocks::EntityApi::IdentityData::Company, and made three
# unrelated models hub through an Increase resource because event_id -> Event happened
# to be unique. Same rule the main walk states 100 lines up; I reused its resolver
# without noticing the inputs differ.
def schema_hit(d, defined) = defined.include?(d) ? d : nil

cols.each do |col, models|
  next if models.uniq.size < 2
  # guard with the SAME resolution the edge uses, or a column resolving only by suffix
  # gets both fk edges and the pair explosion this guard exists to prevent
  next if schema_hit(camelize(col.sub(/_id\z/, "")), defined)
  # sort before pairing: cols accumulates in ARGV order, so an unsorted combination
  # emits [a,b] or [b,a] depending on which file was read first
  models.uniq.sort.combination(2) { |a, b| schema_edges << [a, b, "shares_column"] }
end

schema_resolved = schema_edges.filter_map do |s, d, k|
  next unless defined.include?(s)
  hit = schema_hit(d, defined)
  hit && hit != s ? [s, hit, k] : nil
end.uniq

$stderr.puts "schema edges: #{schema_resolved.size} " \
             "(fk #{schema_resolved.count { |e| e[2] == 'fk' }}, " \
             "assoc #{schema_resolved.count { |e| e[2] == 'assoc' }}, " \
             "shares_column #{schema_resolved.count { |e| e[2] == 'shares_column' }})"

out = ENV.fetch("GRAPH_OUT", "/tmp")
all_edges = (resolved.map { |s,d| [s,d,"references"] } + schema_resolved).uniq
File.write("#{out}/graph-edges.tsv", all_edges.sort.map { |s,d,k| "#{s}\t#{d}\t#{k}\n" }.join)
File.write("#{out}/graph-nodes.tsv", nodes.sort.map { |n,(f,l)| "#{n}\t#{f}\t#{l}\n" }.join)
