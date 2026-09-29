require "set"

module ConceptMap
  STRUCTURAL = %w[Types Mutations QueryResolvers Concerns Api TypedStateMachineV2 Temporal
                  TemporalUtils DataWarehouse Oncall Maintenance SorbetTypes Resolvers
                  Inputs Enums Interfaces Subscriptions Loaders Policies Serializers
                  ApplicationRecord ErrorTracker].to_set

  MIN_KEY_LENGTH = 4

  def self.stem(s)
    return s[0..-4] + "y" if s.end_with?("ies")
    return s[0..-3]       if s.end_with?("es") && s[-3] =~ /[sxzh]/
    return s[0..-2]       if s.end_with?("s") && !s.end_with?("ss")
    s
  end

  def self.slugify(key) = key.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase

  def self.key_for(symbol)
    top = symbol.split("::").first
    return nil if STRUCTURAL.include?(top)
    key = stem(top)
    key.length < MIN_KEY_LENGTH ? nil : key
  end

  # Why a symbol was dropped, so seed-concepts.rb can report it instead of losing it quietly.
  # Svb, Fx and Tag are real namespaces that fall under MIN_KEY_LENGTH.
  def self.short_key(symbol)
    top = symbol.split("::").first
    return nil if STRUCTURAL.include?(top)
    key = stem(top)
    key.length < MIN_KEY_LENGTH ? key : nil
  end

  def self.slug_for(symbol)
    key = key_for(symbol)
    key && slugify(key)
  end
end
