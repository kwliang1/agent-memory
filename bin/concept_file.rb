require "set"

module ConceptFile
  MACHINE_BEGIN = "<!-- machine-owned: regenerated every run, never hand-edit -->"
  MACHINE_END = "<!-- end machine-owned -->"
  NEW_FILE_TAIL = "\n\n## Judgment\n"
  FRONTMATTER = "---"
  FENCE_LINE = /\A {0,3}(`{3,}|~{3,})/
  FIELD_KEYS = %w[symbols files indexed].to_set

  # head is the frontmatter's contents, body the generated fields, end_offset the byte
  # at which MACHINE_END begins. The slices are handed over rather than the indices
  # that produce them: callers previously re-derived `(first + 1)...last` for
  # themselves, and when the layout moved, every one of those had to be re-checked by
  # hand against a `first` that had quietly changed meaning.
  Block = Struct.new(:head, :body, :end_offset)

  # The machine block is located by structural position, never by searching the file for
  # a marker: MACHINE_BEGIN is line 1, the frontmatter opens directly below it, and the
  # block runs to MACHINE_END. Searching was the defect — a fence opened in the
  # frontmatter swallowed the real MACHINE_END and the boundary landed inside the prose,
  # which the writer then replaced.
  #
  # MACHINE_BEGIN sits ABOVE the frontmatter, not below it. Below, the frontmatter read
  # as the author's while the writer rewrote it on every run, so an edit to `related:`
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
      if lines.first == FRONTMATTER && lines.include?(MACHINE_BEGIN)
        return [nil, "#{path}: the machine marker sits below the frontmatter — that is the old layout, and everything above `#{MACHINE_END}` is machine-owned now. Delete this file and re-seed; anything under `## Judgment` must be moved by hand first"]
      end
      return [nil, "#{path}: first line is not `#{MACHINE_BEGIN}` — refusing, this is not a concept file"]
    end
    if lines[1] != FRONTMATTER
      return [nil, "#{path}: line 2 is not `#{FRONTMATTER}` — refusing, the frontmatter must open directly below the machine marker"]
    end
    close = (2...lines.size).find { |i| lines[i] == FRONTMATTER }
    if !close
      return [nil, "#{path}: frontmatter opened at line 2 and never closed with `#{FRONTMATTER}` — refusing"]
    end
    last = ((close + 1)...lines.size).find { |i| lines[i] == MACHINE_END }
    if !last
      return [nil, "#{path}: no line below the frontmatter is exactly `#{MACHINE_END}` — refusing, the machine block has no end"]
    end
    # Both scans cover the frontmatter, not just the fields. The close scan above runs
    # to the first `---` it finds, which in a malformed file can sit far below the real
    # MACHINE_END — so a second marker quoted in the prose becomes the boundary and the
    # writer rewrites straight through the author's judgment.
    stray = (1...last).find { |i| lines[i] == MACHINE_BEGIN || lines[i] == MACHINE_END }
    if stray
      return [nil, "#{path}: `#{lines[stray]}` inside the machine block at line #{stray + 1} — refusing, the boundary is ambiguous"]
    end
    # The block is machine-rendered and never contains a fence, so one here means the file
    # was hand-edited. Refusing beats skipping the line: deciding what a fence encloses is
    # where the old scanner diverged from GFM, and that divergence smuggled fields past
    # the loader.
    fence = (1...last).find { |i| lines[i] =~ FENCE_LINE }
    if fence
      return [nil, "#{path}: a code fence inside the machine block at line #{fence + 1} — refusing, the block is machine-written and never contains one"]
    end


    # The same argument, applied to the field region: it is machine-rendered and holds
    # nothing but FIELD_KEYS, so a line that is not one means the boundary is not where
    # this file reads. That happens whenever the block's own end marker is gone and the
    # author quoted the marker in their judgment — a habit three sections of this suite
    # establish authors have. `last` then lands on the prose marker, the stray scan above
    # finds nothing because the real marker is not there to find, and the writer replaces
    # the judgment with whatever sits under the quoted line. Exit 0, no warning.
    alien = ((close + 1)...last).find { |i| !FIELD_KEYS.include?(lines[i].partition(":").first) }
    if alien
      return [nil, "#{path}: `#{lines[alien]}` between the frontmatter and `#{MACHINE_END}` at line #{alien + 1} — refusing, the machine block holds only #{FIELD_KEYS.to_a.join(', ')} and this boundary is not where the file reads"]
    end

    [Block.new(lines[2...close], lines[(close + 1)...last], offsets[last]), nil]
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

    seen = Set.new
    block.body.each do |line|
      key, _, value = line.partition(":")
      next if !FIELD_KEYS.include?(key)
      if seen.include?(key)
        count = block.body.count { |l| l.partition(":").first == key }
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
