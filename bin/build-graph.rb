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
      nodes[fqn] ||= [path, node.location.start_line]
      node.compact_child_nodes.each { |c| walk.(c, stack + [name]) }
      return
    when Prism::ConstantReadNode, Prism::ConstantPathNode
      unless stack.empty?
        t = node.slice
        edges << [stack.join("::"), t] unless NOISE.include?(t) || t.length < 3
      end
    end
    node.compact_child_nodes.each { |c| walk.(c, stack) }
  end
  walk.(res.value, [])
end

# keep only edges whose target resolves to a node we actually defined
defined = nodes.keys.to_set
resolved = edges.map { |s, d|
  hit = defined.include?(d) ? d : defined.find { |n| n.end_with?("::#{d}") }
  hit ? [s, hit] : nil
}.compact.uniq
resolved.reject! { |s, d| s == d }

out = Hash.new(0); resolved.each { |s, _| out[s] += 1 }
inn = Hash.new(0); resolved.each { |_, d| inn[d] += 1 }

puts "nodes (class/module):  #{nodes.size}"
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
File.write("#{out}/graph-edges.tsv", resolved.map { |s,d| "#{s}\t#{d}" }.join("\n"))
File.write("#{out}/graph-nodes.tsv", nodes.map { |n,(f,l)| "#{n}\t#{f}\t#{l}" }.join("\n"))
