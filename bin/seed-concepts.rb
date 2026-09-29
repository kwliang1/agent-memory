#!/usr/bin/env ruby
# Write one markdown file per concept, from seeds/<repo>-concepts.tsv plus the graph db.
# Usage: seed-concepts.rb <repo-path> <db>

require "fileutils"
require "open3"
require "set"
require_relative "concept_file"
require_relative "concept_map"

PROG = File.basename(__FILE__)
SAFE_NAME = /\A[A-Za-z0-9._-]+\z/

Concept = Struct.new(:slug, :related, :symbols, :files)

def die(message)
  warn "#{PROG}: #{message}"
  exit 1
end

def unsafe(value) = value.gsub(/[^A-Za-z0-9._-]/, "?")

def git(repo, *args)
  out, status = Open3.capture2("env", "-u", "GIT_DIR", "-u", "GIT_WORK_TREE",
                               "git", "-C", repo, "-c", "core.quotePath=false", *args)
  [out.chomp, status.success?]
end

def sqlite(db, query)
  out, status = Open3.capture2("sqlite3", "-cmd", ".timeout 5000", "-separator", "\t", db, query)
  die "could not read #{db}" if !status.success?
  out
end

def sql_quote(value) = "'#{value.gsub("'", "''")}'"

def render_machine_head(concept, repo, indexed)
  lines = [ConceptFile::MACHINE_BEGIN, ConceptFile::FRONTMATTER, "concept: [#{repo}, #{concept.slug}]"]
  if !concept.related.empty?
    lines << "related:"
    concept.related.each { |slug| lines << "  - [#{repo}, #{slug}]" }
  end
  lines.push(ConceptFile::FRONTMATTER,
             "symbols:  #{concept.symbols.join(', ')}",
             "files:    #{concept.files.join(', ')}",
             "indexed:  #{indexed}",
             ConceptFile::MACHINE_END)
  lines.join("\n")
end

def write_concept(path, machine_head, tail)
  # temp + rename, not binwrite: binwrite truncates the only copy of the prose before
  # it writes. Temp + rename does NOT stop symlink-following on its own though -- it
  # moves the exposure from path to path.tmp, and rename then installs that symlink
  # as the concept file. NOFOLLOW closes it: a symlink at the temp raises ELOOP, the
  # caller's SystemCallError rescue turns that into a refusal, and the original file
  # is left exactly as it was.
  temp = "#{path}.tmp"
  File.open(temp, File::WRONLY | File::CREAT | File::TRUNC | File::NOFOLLOW, 0o644) do |f|
    f.binmode
    f.write(machine_head.b + tail)
  end
  File.rename(temp, path)
end

die "usage: #{PROG} <repo-path> <db>" if ARGV.size != 2 || ARGV.any?(&:empty?)
repo_path, db = ARGV
die "no such path: #{repo_path}" if !File.exist?(repo_path)
die "no such db: #{db}" if !File.file?(db)

_, ok = git(repo_path, "rev-parse", "--git-dir")
die "not a git repo: #{repo_path}" if !ok
worktrees, ok = git(repo_path, "worktree", "list", "--porcelain")
main_worktree = worktrees.lines.first.to_s[/\Aworktree (.*)/, 1]
die "could not resolve the main worktree for #{repo_path}" if !ok || !main_worktree
repo = File.basename(main_worktree)
die "unsafe repo name: #{unsafe(repo)}" if !repo.match?(SAFE_NAME)
if File.realpath(repo_path) != File.realpath(main_worktree)
  die "#{repo_path} is a linked worktree of #{main_worktree} — concepts would be filed under #{repo} but stamped at this worktree's HEAD, and that sha dies with the branch"
end
own_toplevel, ok = git(repo_path, "rev-parse", "--show-toplevel")
die "could not resolve the toplevel of #{repo_path}" if !ok
if File.realpath(repo_path) != File.realpath(own_toplevel)
  die "#{repo_path} is not a worktree root — git reports diffs relative to #{own_toplevel}, so a concept seeded here could never go stale"
end
indexed, ok = git(repo_path, "rev-parse", "--verify", "HEAD^{commit}")
die "#{repo_path} has no commits — nothing to stamp a concept against" if !ok

# The symbols and files below come from the `node` table, and `indexed` is HEAD. If the
# graph was built at an older commit those are two different reads, and the concept is
# then certified fresh at a commit whose content it never saw -- unrecoverably, because
# theme.sh computes staleness as `git diff <last_indexed_sha>`, a window that opens
# after the content it missed. The working-tree guard below cannot see this: a clean
# checkout at a newer commit passes it.
# Ask whether the table is there before reading it. Every db built before the stamp
# landed has no graph_stamp, and sqlite3 exits non-zero on a missing table, so
# sqlite() would die with "could not read <db>" — never reaching the line below that
# says what to actually do about it.
has_stamp = sqlite(db, "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'graph_stamp'").strip
stamped = has_stamp == "0" ? "" : sqlite(db, "SELECT head_sha FROM graph_stamp WHERE repo = #{sql_quote(repo)}").strip
die "the graph in #{db} carries no build stamp for #{repo} — run bin/index.sh" if stamped.empty?
if stamped != indexed
  die "the graph in #{db} was built at #{stamped[0, 9]} and #{repo} is at #{indexed[0, 9]} — run bin/index.sh, or a concept will be stamped at a commit it never read"
end

root = File.expand_path("..", __dir__)
seeds = File.join(ENV.fetch("SEEDS_DIR", File.join(root, "seeds")), "#{repo}-concepts.tsv")
concepts_dir = File.join(ENV.fetch("CONCEPTS_DIR", File.join(root, "concepts")), repo)
die "no seed list: #{seeds}" if !File.file?(seeds)

lines = File.readlines(seeds, chomp: true)
die "#{seeds}: first column of the first line is not `concept` — expected the header derive-concepts.rb writes" if lines.first.to_s.split("\t").first != "concept"
rows = lines.drop(1).reject(&:empty?).map { |line| line.split("\t") }
die "no concepts in #{seeds}" if rows.empty?

seeded = rows.map do |row|
  slug = row[0].to_s
  die "unsafe slug in #{seeds}: #{unsafe(slug)} — it becomes a file name and a theme key" if !slug.match?(SAFE_NAME)
  related = row[5].to_s.split(" ").map { |token| token.sub(/\(\d+\)\z/, "") }
  related.each do |other|
    die "unsafe related slug in #{seeds} for #{slug}: #{unsafe(other)}" if !other.match?(SAFE_NAME)
  end
  Concept.new(slug, related, [], [])
end
duplicate = seeded.map(&:slug).tally.find { |_, count| count > 1 }
die "duplicate concept in #{seeds}: #{duplicate.first}" if duplicate

by_slug = Hash.new { |hash, key| hash[key] = [] }
short_dropped = Hash.new { |hash, key| hash[key] = [] }
sqlite(db, "SELECT name, path FROM node WHERE repo = #{sql_quote(repo)} ORDER BY name")
  .each_line(chomp: true) do |line|
  symbol, path = line.split("\t")
  next if !symbol || !path
  slug = ConceptMap.slug_for(symbol)
  if slug
    by_slug[slug] << [symbol, path]
  elsif (short = ConceptMap.short_key(symbol))
    short_dropped[short] << symbol
  end
end

uncommitted, ok = git(repo_path, "-c", "diff.renames=false", "diff", "--name-only", "HEAD", "--")
die "could not check for uncommitted changes in #{repo_path}" if !ok
uncommitted = uncommitted.split("\n").to_set

FileUtils.mkdir_p(concepts_dir)

created = 0
updated = 0
refused = 0
symbols = 0
files = Set.new
seeded.each do |concept|
  members = by_slug[concept.slug]
  path = File.join(concepts_dir, "#{concept.slug}.md")
  if members.empty?
    warn "#{PROG}: #{path}: no symbol in the graph maps to `#{concept.slug}` — refusing to write a concept with no members; re-derive #{File.basename(seeds)}"
    refused += 1
    next
  end
  concept.symbols = members.map(&:first).uniq.sort
  concept.files = members.map(&:last).uniq.sort
  commas = (concept.symbols + concept.files).select { |value| value.include?(",") }
  if !commas.empty?
    warn "#{PROG}: #{path}: a comma in #{commas.join(' ')} — the machine block separates on commas and could not be read back"
    refused += 1
    next
  end
  unread = concept.files.select { |file| uncommitted.include?(file) }
  if !unread.empty?
    warn "#{PROG}: #{path}: uncommitted changes in #{unread.join(' ')} — refusing to stamp at HEAD, the graph cannot have read content HEAD does not carry"
    refused += 1
    next
  end

  machine_head = render_machine_head(concept, repo, indexed)
  begin
    if File.exist?(path)
      tail, error = ConceptFile.split(File.binread(path), path)
      if error
        warn "#{PROG}: #{error}"
        refused += 1
        next
      end
      write_concept(path, machine_head, tail)
      updated += 1
    else
      write_concept(path, machine_head, ConceptFile::NEW_FILE_TAIL.b)
      created += 1
    end
  rescue SystemCallError => e
    warn "#{PROG}: #{path}: #{e.message} — refusing this concept, continuing with the rest"
    refused += 1
    next
  end
  symbols += concept.symbols.size
  files.merge(concept.files)
end

puts "#{created + updated} concepts in #{concepts_dir} (#{created} created, #{updated} updated): " \
     "#{symbols} symbols, #{files.size} files at #{indexed[0, 9]}"
if !short_dropped.empty?
  summary = short_dropped.sort_by { |key, found| [-found.size, key] }
                         .map { |key, found| "#{key} (#{found.size})" }
  warn "#{PROG}: #{short_dropped.values.sum(&:size)} symbol(s) belong to no concept because " \
       "their namespace is under #{ConceptMap::MIN_KEY_LENGTH} characters: #{summary.join(', ')}"
end
warn "#{PROG}: refused #{refused} concept(s)" if refused > 0
exit(refused > 0 ? 1 : 0)
