# frozen_string_literal: true

RSpec.describe 'Translating value object errors through I18n' do
  class I18nValue < ActiveRecordValueObjects::AbstractValue
    validates :name, presence: true
    validates :code, length: { maximum: 3 }
    validates :note, presence: { message: 'needs a note' }

    attribute :name, Types::String.optional
    attribute :code, Types::String.optional
    attribute :note, Types::String.optional
  end

  class I18nRecordBase
    include ActiveModel::Validations
    include ActiveRecordValueObjects::ValueAttributeSupport

    attr_accessor :raw_value, :raw_values

    # value_attribute wraps these via super, standing in for AR's jsonb accessors
    def value=(hash)
      @raw_value = hash
    end

    def value
      @raw_value
    end

    def values=(hash)
      @raw_values = hash
    end

    def values
      @raw_values
    end
  end

  class I18nRecord < I18nRecordBase

    value_attribute :value, I18nValue.optional
    value_attribute :values, ActiveRecordValueObjects::AbstractValue::Types::Array.of(I18nValue).optional
  end

  let(:invalid) { I18nValue.new(name: nil, code: 'toolong', note: nil) }

  def messages_for(attribute)
    record = I18nRecord.new
    record.value = invalid
    record.values = [invalid]
    record.validate
    record.errors.messages_for(attribute)
  end

  def store(translations)
    I18n.backend.store_translations(:en, translations)
  end

  # load the shipped locale files first so they don't overwrite stored translations
  before { I18n.backend.eager_load! }
  after { I18n.backend.reload! }

  context 'without translations' do
    it 'keeps the default English messages' do
      expect(messages_for(:'value/name')).to eq ["can't be blank"]
      expect(messages_for(:'value/code')).to eq ['is too long (maximum is 3 characters)']
      expect(messages_for(:'values/0/name')).to eq ["can't be blank"]
    end

    it 'keeps custom messages' do
      expect(messages_for(:'value/note')).to eq ['needs a note']
    end
  end

  context 'with a translation scoped to the record' do
    it 'uses it for a value attribute' do
      store(activemodel: { errors: { models: { i18n_record: { attributes: { 'value/name': { blank: 'needs a name' } } } } } })

      expect(messages_for(:'value/name')).to eq ['needs a name']
    end

    it 'uses it for every element of an array attribute, keyed without the index' do
      store(activemodel: { errors: { models: { i18n_record: { attributes: { 'values/name': { blank: 'needs a name' } } } } } })

      expect(messages_for(:'values/0/name')).to eq ['needs a name']
    end

    it 'interpolates the validation options' do
      store(activemodel: { errors: { models: { i18n_record: { attributes: { 'value/code': { too_long: 'at most %{count}' } } } } } })

      expect(messages_for(:'value/code')).to eq ['at most 3']
    end

    it 'overrides a custom message, as Rails does for its own attributes' do
      store(activemodel: { errors: { models: { i18n_record: { attributes: { 'value/note': { blank: 'translated' } } } } } })

      expect(messages_for(:'value/note')).to eq ['translated']
    end
  end

  context 'with a translation scoped to the value object' do
    it 'still uses it' do
      store(activemodel: { errors: { models: { i18n_value: { attributes: { name: { blank: 'value needs a name' } } } } } })

      expect(messages_for(:'value/name')).to eq ['value needs a name']
    end
  end

  context 'with errors on base' do
    class I18nBaseValue < ActiveRecordValueObjects::AbstractValue
      validate { errors.add(:base, 'is bad') }
      validate { errors.add(:base, :invalid) }

      attribute :name, Types::String.optional
    end

    class I18nBaseRecord < I18nRecordBase
      value_attribute :values, ActiveRecordValueObjects::AbstractValue::Types::Array.of(I18nBaseValue).optional
    end

    it 'keeps their messages on array elements' do
      record = I18nBaseRecord.new
      record.values = [I18nBaseValue.new(name: nil)]
      record.validate

      expect(record.errors.messages_for(:'values/0/base')).to eq ['is bad', 'is invalid']
    end
  end

  context 'with a global translation for the type' do
    it 'uses it' do
      store(errors: { messages: { blank: 'is required' } })

      expect(messages_for(:'value/name')).to eq ['is required']
    end

    it 'keeps custom messages' do
      store(errors: { messages: { blank: 'is required' } })

      expect(messages_for(:'value/note')).to eq ['needs a note']
    end
  end
end
