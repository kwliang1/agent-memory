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

nodes = {}   # fqn -> [file, line]
edges = []   # [src_fqn, dst_const]

ARGV.each do |path|
  src = File.read(path) rescue next
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
inn.sort_by { |_, v| -v }.first(12).each { |n, v| puts "  #{v.to_s.rjust(5)}  #{n}" }

out = ENV.fetch("GRAPH_OUT", "/tmp")
File.write("#{out}/graph-edges.tsv", resolved.map { |s,d| "#{s}\t#{d}\n" }.join)
File.write("#{out}/graph-nodes.tsv", nodes.map { |n,(f,l)| "#{n}\t#{f}\t#{l}\n" }.join)
