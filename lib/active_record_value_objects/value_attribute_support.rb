# frozen_string_literal: true
module ActiveRecordValueObjects
  class Validator < ActiveModel::Validator
    def validate(record)
      record.__value_attribute_registry.each do |(attr, _value)|
        value = record.send(attr)
        if value.present? && value.is_a?(Array)
          value.each_with_index do |v, i|
            next if v.validate

            v.errors.each do |e|
              add_error(record, "#{attr}/#{i}/#{e.attribute}", e, index_free_path: "#{attr}/#{e.attribute}")
            end
          end
        elsif value.present? && !value.validate
          value.errors.each do |e|
            add_error(record, "#{attr}/#{e.attribute}", e)
          end
        end
      end
    end

    private

    # Rails looks the error up at <scope>.errors.models.<record>.attributes.<path>.<type> first
    # and falls back to `message:`, the value object's own (already translated) message.
    def add_error(record, path, error, index_free_path: nil)
      options = error.options.except(*ActiveModel::Error::CALLBACKS_OPTIONS, :message)
      message = error.message
      # array elements: also try the key without the index, e.g. attributes.items/name.blank
      message = translate_for(record, index_free_path, error, options, message) if index_free_path
      record.errors.add(path, error.type, **options, message: message)
    end

    def translate_for(record, path, error, options, default)
      return default unless error.type.is_a?(Symbol) && record.class.respond_to?(:i18n_scope)

      I18n.t(:"#{record.class.i18n_scope}.errors.models.#{record.model_name.i18n_key}.attributes.#{path}.#{error.type}",
             **options,
             default: default,
             model: record.model_name.human,
             attribute: record.class.human_attribute_name(path),
             value: error.attribute == :base ? nil : error.base.read_attribute_for_validation(error.attribute))
    end
  end


  class Attribute

    def initialize(value_name, value_class, builder: nil)
      @value_name = value_name
      @builder = builder
      @is_array = value_class.is_a?(Array)
      @is_hash = value_class.is_a?(Hash)
      @value_class = @is_array ? value_class.first : value_class

      while @value_class.is_a?(Dry::Types::Sum::Constrained)
        @value_class = @value_class.right
      end

      # Types::Array.of(X) arrives as a dry-types array; treat it like the [X] literal
      if @value_class.respond_to?(:member)
        @is_array = true
        @value_class = @value_class.member
      end

      unless @is_hash || @value_class < ActiveRecordValueObjects::AbstractValue
        raise ArgumentError.new("You tried to define value accessors for #{value_name} using #{@value_class} which does not descend from Values::Base")
      end
    end

    # Called when setting
    def to_jsonb(value)

      # first memoize hash values
      @memo_value = if value.nil?
                      @is_array ? [] : value
                    else
                      @is_array ? value.map { |v| coerce(v) } : coerce(value)
                    end

      @is_array ? @memo_value.map(&:to_hash) : @memo_value&.to_hash
    end

    def from_jsonb(value, parent)
      # memoize the access for later
      @memo_value ||= if @is_array
                        (value || []).map do |v|
                          ret = @value_class.new(v)
                          ret.parent = parent
                          ret
                        end
                      elsif @is_hash
                        value || {}
                      else
                        ret = @value_class.new(value.respond_to?(:deep_transform_keys) ? value.deep_transform_keys! { |key| underscore(key) } : {})
                        ret.parent = parent
                        ret
                      end
      @memo_value
    end

    def reset!
      @memo_value = nil
    end

    private

    def coerce(value)

      # If a builder has been provided we can call a method provided on the class
      # which will take the provided value and convert it into the value class
      if @builder
        value = @value_class.send(@builder, value)
      end

      # If the passed in value is a hash, let's accept it, deep transform it to use
      # the value object schema and then construct our value class, this enforces the
      # schema
      # TODO: Bring this back
      if value.is_a?(ActionController::Parameters)
        value = value.to_unsafe_hash
      end
      if value.is_a?(Hash)
        value = @value_class.new(value.deep_transform_keys! { |key| underscore(key) })
      end

      unless value.is_a?(@value_class)
        raise ArgumentError.new("You tried to set #{@value_name} to an instance of #{value.class.name} when it only accepts #{@value_class}")
      end

      value
    end

    def underscore(value)
      if value.is_a? Symbol
        return value.to_s.underscore.to_sym
      elsif value.is_a? String
        return value.underscore
      end

      value
    end
  end

  module ValueAttributeSupport
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Decorate the reload method to reset the memoized values
    def reload(options = nil)
      ret = super(options)

      __value_attribute_registry.values.each do |attribute|
        attribute.reset!
      end

      ret
    end

    def __value_attribute_registry
      @value_attribute_registry ||= {}
    end

    # @overload
    # This method allows use to recursively extract values from the
    # pointer attribute names generated by the validations.
    def read_attribute_for_validation(attribute)
      # a value object's :base error has no value, as with Rails' own :base
      return nil if attribute.to_s.end_with?('/base')

      attribute.to_s.split('/').reduce(self) do |acc, attr|
        acc.is_a?(Array) && attr.match?(/\A\d+\z/) ? acc[attr.to_i] : acc.send(attr)
      end
    end

    module ClassMethods

      # Defines a new value_attribute
      #
      # @usage value_attribute :value_menu, Values::Menus::Menu, builder: :from_ar_menu
      # @param [Symbol] value_name
      # @param [Class] value_class
      # @param [Lambda] builder
      # @!macro [attach] value_attribute
      #   @return [$2] the $1 $0
      def value_attribute(value_name, value_class, builder: nil, allow_nil: false)
        # This bit of mess defines a lazily instantiate attribute to decorate the
        # AR value accessor
        attr_key = "__value_attribute_#{value_name}"
        instance_attr_key = "@#{attr_key}"

        if respond_to?(:validates_with) && validators.none?(::ActiveRecordValueObjects::Validator)
          validates_with ::ActiveRecordValueObjects::Validator
        end

        define_method(attr_key) do

          # lazily build an instance of the attribute, store it in the registry
          unless instance_variable_defined?(instance_attr_key)
            attribute = Attribute.new(value_name, value_class, builder: builder)
            __value_attribute_registry[value_name] = attribute
            instance_variable_set(instance_attr_key, attribute)
          end
          instance_variable_get(instance_attr_key)
        end

        # Defines a setter method that converts your virtus struct into a hash that
        # can be stored in a jsonb column
        define_method(:"#{value_name}=") do |value|
          va = self.send(attr_key)

          super(va.to_jsonb(value))
        end

        # defines a getter for the value which gets the jsonb field
        # and wraps it in your model
        define_method(value_name) do
          va = self.send(attr_key)
          attrs = super() || attributes[value_name.to_s]

          if allow_nil && (attrs.nil? || attrs.empty?)
            nil
          else
            va.from_jsonb(attrs, self)
          end
        end
      end
    end
  end
end
