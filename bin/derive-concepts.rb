nodes = File.readlines(ENV.fetch("GRAPH_OUT","/tmp") + "/graph-nodes.tsv").map { |l| l.chomp.split("\t") }
edges = File.readlines(ENV.fetch("GRAPH_OUT","/tmp") + "/graph-edges.tsv").map { |l| l.chomp.split("\t") }
indeg = Hash.new(0); edges.each { |_, d| indeg[d] += 1 }
STRUCTURAL = %w[Types Mutations QueryResolvers Concerns Api TypedStateMachineV2 Temporal
                TemporalUtils DataWarehouse Oncall Maintenance SorbetTypes Resolvers
                Inputs Enums Interfaces Subscriptions Loaders Policies Serializers
                ApplicationRecord ErrorTracker].to_set
def stem(s)
  return s[0..-4] + "y" if s.end_with?("ies")
  return s[0..-3]       if s.end_with?("es") && s[-3] =~ /[sxzh]/
  return s[0..-2]       if s.end_with?("s") && !s.end_with?("ss")
  s
end
c = Hash.new { |h,k| h[k] = { m: [], w: 0, f: [] } }
nodes.each do |n, path, line|
  top = n.split("::").first
  next if STRUCTURAL.include?(top)
  key = stem(top); next if key.length < 4
  c[key][:m] << n; c[key][:w] += indeg[n]; c[key][:f] << path
end
ranked = c.reject { |_, v| v[:m].size < 2 && v[:w] < 5 }
          .sort_by { |k, v| -(v[:w] + v[:m].size * 3) }
File.open("seeds/treasury-concepts.tsv", "w") do |io|
  io.puts "concept\tsymbols\tin_degree\tfiles\ttop_symbol"
  ranked.each do |k, v|
    slug = k.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
    io.puts [slug, v[:m].size, v[:w], v[:f].uniq.size, v[:m].min_by(&:length)].join("\t")
  end
end
puts "wrote #{ranked.size} concepts"
