#!/usr/bin/env ruby
# Print the machine block of each concept file as TSV for bin/load-concepts.sh.
# Usage: read-concepts.rb <file>...

require_relative "concept_file"

PROG = File.basename(__FILE__)

rows = []
ARGV.each do |path|
  parsed, error = ConceptFile.fields(File.binread(path), path)
  if error
    warn "#{PROG}: #{error}"
    exit 1
  end
  slug = File.basename(path, ".md")
  rows << [slug, "concept", parsed[:concept]]
  rows << [slug, "indexed", parsed[:indexed]]
  parsed[:symbols].each { |symbol| rows << [slug, "symbol", symbol] }
  parsed[:files].each { |file| rows << [slug, "file", file] }
end

rows.each { |row| puts row.join("\t") }
