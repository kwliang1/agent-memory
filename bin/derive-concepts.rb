#!/usr/bin/env ruby
# Derive domain concepts from the symbol graph.
#
# A concept merges a model with its service namespace by stem, so AchPull and
# AchPulls::* become one `ach_pull`. Output is seeds/<repo>-concepts.tsv, for review
# by hand before anything is written.
#
# Deterministic: every sort carries a tiebreaker, because Ruby's sort_by is not stable
# and min_by returns the first of equal-length ties in insertion order.

require_relative "concept_map"

out_dir = ENV.fetch("SEEDS_OUT", File.expand_path("../seeds", __dir__))
graph   = ENV.fetch("GRAPH_OUT", "/tmp")
repo    = ENV.fetch("REPO_NAME", "treasury")

nodes = File.readlines("#{graph}/graph-nodes.tsv").map { |l| l.chomp.split("\t")[0] }
edges = File.readlines("#{graph}/graph-edges.tsv").map { |l| l.chomp.split("\t") }
indeg = Hash.new(0); edges.each { |_, d| indeg[d] += 1 }

# symbol -> concept key
owner = {}
c = Hash.new { |h, k| h[k] = { m: [], w: 0, f: [] } }
File.readlines("#{graph}/graph-nodes.tsv").each do |line|
  n, path, _ = line.chomp.split("\t")
  key = ConceptMap.key_for(n)
  next if !key
  c[key][:m] << n
  c[key][:w] += indeg[n]
  c[key][:f] << path
  owner[n] = key
end

ranked = c.reject { |_, v| v[:m].size < 2 && v[:w] < 5 }
          .sort_by { |k, v| [-(v[:w] + v[:m].size * 3), k] }
kept = ranked.map(&:first).to_set

# concept -> concept edges, aggregated from symbol edges. This is the `related:` block
# in the concept template: a family like outgoing_wire / outgoing_payment /
# external_wire_account is invisible in a per-concept row and obvious here.
rel = Hash.new(0)
edges.each do |s, d|
  a, b = owner[s], owner[d]
  next unless a && b && a != b && kept.include?(a) && kept.include?(b)
  rel[[a, b]] += 1
end
related = Hash.new { |h, k| h[k] = [] }
rel.each { |(a, b), n| related[a] << [n, b]; related[b] << [n, a] }

File.write(File.join(out_dir, "#{repo}-concepts.tsv"),
  (["concept\tsymbols\tin_degree\tfiles\ttop_symbols\trelated"] +
   ranked.map do |k, v|
     # top 3 by in-degree, not one by name length: outgoing_payment showing only
     # `OutgoingPayment` under-describes 48 symbols.
     tops = v[:m].sort_by { |s| [-indeg[s], s] }.first(3).join(" ")
     # dedupe (a->b and b->a both land here), strongest first
     rl = related[k].group_by(&:last).map { |n, rows| [rows.sum(&:first), n] }
                    .sort_by { |n, name| [-n, name] }.first(3)
                    .map { |n, name| "#{ConceptMap.slugify(name)}(#{n})" }.join(" ")
     [ConceptMap.slugify(k), v[:m].size, v[:w], v[:f].uniq.size, tops, rl].join("\t")
   end).join("\n") + "\n")

puts "wrote #{ranked.size} concepts, #{rel.size} concept-edges"
