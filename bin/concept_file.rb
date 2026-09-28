require "set"

module ConceptFile
  MACHINE_BEGIN = "<!-- machine-owned: regenerated every run, never hand-edit -->"
  MACHINE_END = "<!-- end machine-owned -->"
  NEW_FILE_TAIL = "\n\n## Judgment\n"
  FRONTMATTER = "---"
  FENCE_LINE = /\A {0,3}(`{3,}|~{3,})/
  FIELD_KEYS = %w[symbols files indexed].to_set

  Block = Struct.new(:lines, :head, :first, :last, :end_offset)

  # The machine block is located by structural position, never by searching the file for a
  # marker: MACHINE_BEGIN is line 1, the frontmatter opens directly below it, and the block
  # runs to MACHINE_END. Searching was the defect — a fence opened in the frontmatter
  # swallowed the real MACHINE_END and the boundary landed inside the prose, which the
  # writer then replaced.
  #
  # MACHINE_BEGIN sits ABOVE the frontmatter, not below it. Below, the frontmatter read as
  # the author's while the writer rewrote it on every run, so an edit to `related:`
  # vanished silently. Above, the rule has no ambiguous middle: everything down to
  # MACHINE_END belongs to the machine and everything under it belongs to the author.
  #
  # Anything that does not match this shape is refused and left on disk untouched.
  def self.locate(content, path)
    lines = []
    offsets = []
    offset = 0
    content.each_line do |line|
      lines << line.chomp
      offsets << offset
      offset += line.bytesize
    end

    if lines.first != MACHINE_BEGIN
      return [nil, "#{path}: first line is not `#{MACHINE_BEGIN}` — refusing, this is not a concept file"]
    end
    if lines[1] != FRONTMATTER
      return [nil, "#{path}: line 2 is not `#{FRONTMATTER}` — refusing, the frontmatter must open directly below the machine marker"]
    end
    close = (2...lines.size).find { |i| lines[i] == FRONTMATTER }
    if !close
      return [nil, "#{path}: frontmatter opened at line 2 and never closed with `#{FRONTMATTER}` — refusing"]
    end
    first = close
    last = ((first + 1)...lines.size).find { |i| lines[i] == MACHINE_END }
    if !last
      return [nil, "#{path}: no line below the frontmatter is exactly `#{MACHINE_END}` — refusing, the machine block has no end"]
    end
    stray = (1...last).find { |i| lines[i] == MACHINE_BEGIN || lines[i] == MACHINE_END }
    if stray
      return [nil, "#{path}: `#{lines[stray]}` inside the machine block at line #{stray + 1} — refusing, the boundary is ambiguous"]
    end
    # The block is machine-rendered and never contains a fence, so one here means the file was
    # hand-edited. Refusing beats skipping the line: deciding what a fence encloses is where the
    # old scanner diverged from GFM, and that divergence smuggled fields past the loader.
    fence = (1...last).find { |i| lines[i] =~ FENCE_LINE }
    if fence
      return [nil, "#{path}: a code fence inside the machine block at line #{fence + 1} — refusing, the block is machine-written and never contains one"]
    end

    [Block.new(lines, lines[2...close], first, last, offsets[last]), nil]
  end

  def self.split(content, path)
    block, error = locate(content, path)
    return [nil, error] if error
    [content.byteslice((block.end_offset + MACHINE_END.bytesize)..), nil]
  end

  def self.fields(content, path)
    block, error = locate(content, path)
    return [nil, error] if error

    declared = block.head.select { |line| line.start_with?("concept:") }
    if declared.size > 1
      return [nil, "#{path}: #{declared.size} `concept:` lines in the frontmatter — refusing, the identity is ambiguous"]
    end

    parsed = { concept: nil, indexed: nil, symbols: [], files: [] }
    parsed[:concept] = declared.first[/\[\s*(.*?)\s*\]/, 1] if declared.first

    body = ((block.first + 1)...block.last)
    seen = Set.new
    body.each do |number|
      key, _, value = block.lines[number].partition(":")
      next if !FIELD_KEYS.include?(key)
      if seen.include?(key)
        count = body.count { |i| block.lines[i].partition(":").first == key }
        return [nil, "#{path}: the machine block has #{count} `#{key}:` lines — refusing, the value is ambiguous"]
      end
      seen << key
      case key
      when "indexed" then parsed[:indexed] = value.strip
      when "symbols" then parsed[:symbols] = list(value)
      when "files"   then parsed[:files] = list(value)
      end
    end

    return [nil, "#{path}: no `concept: [repo, slug]` line in the frontmatter"] if !parsed[:concept]
    return [nil, "#{path}: the machine block has no `indexed:` line"] if parsed[:indexed].to_s.empty?
    return [nil, "#{path}: the machine block lists no symbols — refusing to load a theme with no members"] if parsed[:symbols].empty?
    return [nil, "#{path}: the machine block lists no files — a theme with no paths can never go stale"] if parsed[:files].empty?
    [parsed, nil]
  end

  def self.list(value) = value.split(",").map(&:strip).reject(&:empty?)
end
