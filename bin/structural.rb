#!/usr/bin/env ruby
# Usage: structural.rb <graph-nodes.tsv> <graph-edges.tsv> -- TS hubs: busy modules in no concept, or spanning many.

require_relative "concept_map"

HUB_DEGREE = 50
HUB_SPREAD = 25

nodes_tsv, edges_tsv = ARGV
nodes = File.readlines(nodes_tsv, chomp: true, encoding: "BINARY").map { |line| line.split("\t") }
            .select { |_, path| path.to_s.match?(ConceptMap::TS_SOURCE) }
concept = ConceptMap.keys(nodes)

neighbours = Hash.new { |hash, key| hash[key] = [] }
File.foreach(edges_tsv, chomp: true, encoding: "BINARY") do |line|
  src, dst, _ = line.split("\t")
  neighbours[src] << dst
  neighbours[dst] << src
end

nodes.each do |name, _|
  near = neighbours[name]
  next if near.size < HUB_DEGREE
  puts name if !concept[name] || near.filter_map { |n| concept[n] }.uniq.size >= HUB_SPREAD
end
