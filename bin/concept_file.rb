require "set"

module ConceptFile
  MACHINE_BEGIN = "<!-- machine-owned: regenerated every run, never hand-edit -->"
  MACHINE_END = "<!-- end machine-owned -->"
  NEW_FILE_TAIL = "\n\n## Judgment\n"
  FENCE_LINE = /\A {0,3}(`{3,}|~{3,})/
  FIELD_KEYS = %w[symbols files indexed].to_set

  def self.scan(content)
    opens = []
    closes = []
    fenced = Set.new
    open_fence = nil
    offset = 0
    content.each_line.with_index do |line, number|
      bare = line.chomp
      fence = bare[FENCE_LINE, 1]
      if open_fence
        fenced << number
        open_fence = nil if fence && fence[0] == open_fence[0] && fence.length >= open_fence.length
      elsif fence
        fenced << number
        open_fence = fence
      elsif bare == MACHINE_END
        closes << offset
      elsif bare == MACHINE_BEGIN
        opens << number
      end
      offset += line.bytesize
    end
    [opens, closes, fenced]
  end

  def self.boundary_offsets(content) = scan(content)[1]

  def self.split(content, path)
    offsets = boundary_offsets(content)
    if offsets.empty?
      return [nil, "#{path}: no line outside a code fence is exactly `#{MACHINE_END}` — refusing, the boundary would have to be guessed"]
    end
    if offsets.size > 1
      return [nil, "#{path}: #{offsets.size} lines outside a code fence are exactly `#{MACHINE_END}` — refusing, the boundary is ambiguous"]
    end
    [content.byteslice((offsets.first + MACHINE_END.bytesize)..), nil]
  end

  def self.fields(content, path)
    tail, error = split(content, path)
    return [nil, error] if error
    lines = content.byteslice(0, content.bytesize - tail.bytesize).each_line.map(&:chomp)
    opens, _, fenced = scan(content)
    opens = opens.select { |number| number < lines.size }
    return [nil, "#{path}: no line above the boundary outside a code fence is exactly `#{MACHINE_BEGIN}` — refusing, the machine block has no start"] if opens.empty?
    return [nil, "#{path}: #{opens.size} lines above the boundary outside a code fence are exactly `#{MACHINE_BEGIN}` — refusing, the machine block has no single start"] if opens.size > 1
    opened = opens.first

    parsed = { concept: nil, indexed: nil, symbols: [], files: [] }
    declared = lines[0...opened].find { |line| line.start_with?("concept:") }
    parsed[:concept] = declared[/\[\s*(.*?)\s*\]/, 1] if declared
    seen = Set.new
    ((opened + 1)...(lines.size - 1)).each do |number|
      next if fenced.include?(number)
      key, _, value = lines[number].partition(":")
      next if !FIELD_KEYS.include?(key)
      return [nil, "#{path}: the machine block has #{lines[(opened + 1)...-1].count { |l| l.start_with?("#{key}:") }} `#{key}:` lines — refusing, the value is ambiguous"] if seen.include?(key)
      seen << key
      case key
      when "indexed" then parsed[:indexed] = value.strip
      when "symbols" then parsed[:symbols] = value.split(",").map(&:strip).reject(&:empty?)
      when "files"   then parsed[:files] = value.split(",").map(&:strip).reject(&:empty?)
      end
    end

    return [nil, "#{path}: no `concept: [repo, slug]` line above the machine block"] if !parsed[:concept]
    return [nil, "#{path}: the machine block has no `indexed:` line"] if parsed[:indexed].to_s.empty?
    return [nil, "#{path}: the machine block lists no symbols — refusing to load a theme with no members"] if parsed[:symbols].empty?
    return [nil, "#{path}: the machine block lists no files — a theme with no paths can never go stale"] if parsed[:files].empty?
    [parsed, nil]
  end
end
