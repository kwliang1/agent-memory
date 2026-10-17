require "set"

module ConceptMap
  STRUCTURAL = %w[Types Mutations QueryResolvers Concerns Api TypedStateMachineV2 Temporal
                  TemporalUtils DataWarehouse Oncall Maintenance SorbetTypes Resolvers
                  Inputs Enums Interfaces Subscriptions Loaders Policies Serializers
                  ApplicationRecord ErrorTracker].to_set

  MIN_KEY_LENGTH = 4
  SHORT_KEYS = %w[Kyc].to_set

  TS_SOURCE = /\.(ts|tsx|mts|cts)\z/
  TS_LAYERS = File.readlines(File.join(__dir__, "ts-layers.txt"), chomp: true).to_set

  def self.stem(s)
    return s[0..-4] + "y" if s.end_with?("ies")
    return s[0..-3]       if s.end_with?("es") && s[-3] =~ /[sxzh]/
    return s[0..-2]       if s.end_with?("s") && !s.end_with?("ss", "us")
    s
  end

  def self.slugify(key) = key.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase

  def self.key_for(symbol)
    top = symbol.split("::").first
    return nil if STRUCTURAL.include?(top)
    key = stem(top)
    too_short?(key) ? nil : key
  end

  # Why a symbol was dropped, so seed-concepts.rb can report it instead of losing it quietly.
  # Svb, Fx and Tag are real namespaces that fall under MIN_KEY_LENGTH.
  def self.short_key(symbol)
    top = symbol.split("::").first
    return nil if STRUCTURAL.include?(top)
    key = stem(top)
    too_short?(key) ? key : nil
  end

  def self.too_short?(key) = key.length < MIN_KEY_LENGTH && !SHORT_KEYS.include?(key)

  def self.ts_slug(path)
    seg = path.split("/")[0..-2].find { |d| !TS_LAYERS.include?(d.downcase) && d.match?(/\A[A-Za-z]/) }
    return nil if !seg
    words = slugify(seg).split(/[^a-z0-9]+/).reject(&:empty?)
    words[-1] = stem(words[-1]) if words[-1].match?(/[a-z]{4}s\z/) && !words[-1].match?(/(us|is)\z/)
    words.join("_")
  end

  # dataRoom and dataroom are one concept, named by the variant that keeps its word breaks.
  def self.ts_slugs(rows)
    raw = rows.filter_map do |symbol, path|
      slug = ts_slug(path)
      [symbol, slug] if slug && slug.delete("_").length >= MIN_KEY_LENGTH
    end
    canon = raw.map(&:last).uniq.group_by { |slug| slug.delete("_") }
               .transform_values { |variants| variants.max_by { |slug| [slug.count("_"), slug] } }
    raw.to_h { |symbol, slug| [symbol, canon[slug.delete("_")]] }
  end

  def self.ts_short_key(path)
    slug = ts_slug(path)
    slug && slug.delete("_").length < MIN_KEY_LENGTH ? slug : nil
  end

  # symbol => concept key for [symbol, path] rows of either language.
  def self.keys(rows)
    ts, rb = rows.partition { |_, path| path.to_s.match?(TS_SOURCE) }
    rb.filter_map { |symbol, _| (key = key_for(symbol)) && [symbol, key] }.to_h.merge(ts_slugs(ts))
  end

  def self.short(symbol, path)
    path.to_s.match?(TS_SOURCE) ? ts_short_key(path) : short_key(symbol)
  end
end
