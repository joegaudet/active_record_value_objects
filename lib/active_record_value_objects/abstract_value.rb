# frozen_string_literal: true

module ActiveRecordValueObjects
  class AbstractValue < ::Dry::Struct
    include ActiveModel::Validations

    # The record (or value) this value was read from; set by value_attribute readers
    attr_accessor :parent

    module Types
      include Dry.Types()
    end

    def self.new(attributes = default_attributes, safe = false, &)
      # if optional parameters are missing, set them to nil
      schema.each do |key, value|
        if key.optional?
          attributes[key.name] = nil unless attributes.key?(key.name)
        end
      end
      super(attributes, safe, &)
    end

    def to_unsafe_hash
      self.to_hash
    end

    def to_table
      Terminal::Table.new(headings: [:attribute, :value]) do |t|
        attributes.each do |key, value|
          t << [key, value]
        end
      end
    end

    def print_table
      puts to_table
    end

    def dig(*attributes)
      attributes.reduce(self) { |last, attribute| last.send(attribute) }
    end

    def copy_with(attrs = {})
      attrs.each_key do |key|
        raise ArgumentError, "You're trying to copy with attribute #{key} that does not exist on #{self.class}" unless self.attributes.key?(key)
      end

      self.class.new(self.attributes.clone.merge(attrs))
    end

    def is_equal?(other)
      self.attributes.each.all? do |key, value|
        value == other.send(key)
      end
    end

    def to_json_without_nil
      self.to_h.remove_nil_values.to_json
    end

  end
end