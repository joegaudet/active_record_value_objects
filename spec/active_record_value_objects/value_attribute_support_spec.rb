# frozen_string_literal: true

require 'rspec'

RSpec.describe ActiveRecordValueObjects::ValueAttributeSupport do
  class AValueObject < ActiveRecordValueObjects::AbstractValue

    attribute :foo, Types::String.optional
    attribute :bar, Types::String.optional
    attribute :baz_qux, Types::String.optional
  end

  class AValidatedObject < ActiveRecordValueObjects::AbstractValue

    validates :foo, presence: true

    attribute :foo, Types::String.optional
  end

  # The value_attribute macro works by calling
  # super on active record accessor models, so we need
  # to provide those.
  class PoroBase
    include ActiveModel::Validations
    include ActiveRecordValueObjects::ValueAttributeSupport

    attr_accessor :test, :test_foos

    def foo=(hash)
      @test = hash
    end

    def foo
      @test
    end

    def foos=(hash)
      @test_foos = hash
    end

    def foos
      @test_foos
    end

    def reload(options = nil) end
  end

  class Poro < PoroBase
    value_attribute :foo, AValueObject.optional
    value_attribute :foos, ActiveRecordValueObjects::AbstractValue::Types::Array.of(AValueObject).optional
  end

  class ArrayPoro < PoroBase
    include Dry.Types()
    value_attribute :foo, ActiveRecordValueObjects::AbstractValue::Types::Array.of(AValueObject).optional
  end

  class ValidateablePoro < PoroBase
    include Dry.Types()
    value_attribute :foo, AValidatedObject.optional
    value_attribute :foos, ActiveRecordValueObjects::AbstractValue::Types::Array.of(AValidatedObject).optional
  end

  it 'raises an error if the value is not the expected type' do
    expect {
      poro = Poro.new(foo: AValueObject.new())
      poro.foo = 'foo'
    }.to raise_error(ArgumentError)
  end

  it 'raises an error if the value is not the expected type in an array' do
    poro = Poro.new
    foo = Faker::Lorem.word
    bar = Faker::Lorem.word

    poro.foo = AValueObject.new(foo: foo, bar: bar, baz_qux: nil)
    poro.foos = [AValueObject.new(foo: foo, bar: bar, baz_qux: nil)]

    expect(poro.test).to eq({ foo: foo, bar: bar, baz_qux: nil })
    expect(poro.test_foos).to eq([{ foo: foo, bar: bar, baz_qux: nil }])
  end

  it 'converts snake case to camel case' do
    poro = Poro.new
    foo = Faker::Lorem.word
    bar = Faker::Lorem.word

    poro.foo = { 'foo': foo, 'bar': bar, 'bazQux': bar }

    expect(poro.test).to eq({ foo: foo, bar: bar, baz_qux: bar })

    poro.foo = { 'foo': foo, 'bar': bar, 'baz-qux': bar }

    expect(poro.test).to eq({ foo: foo, bar: bar, baz_qux: bar })
  end

  it 'restores from a hash' do
    poro = Poro.new
    foo = Faker::Lorem.word
    bar = Faker::Lorem.word

    poro.test = { foo: foo, bar: bar }
    poro.test_foos = [{ foo: foo, bar: bar }]

    expect(poro.foo.foo).to eq foo
    expect(poro.foo.bar).to eq bar
    expect(poro.foos.first.foo).to eq foo
    expect(poro.foos.first.bar).to eq bar
  end

  it 'memoizes the value on get' do
    poro = Poro.new
    foo = Faker::Lorem.word
    bar = Faker::Lorem.word

    poro.test = { foo: foo, bar: bar }

    expect(poro.foo.object_id).to eq poro.foo.object_id
  end

  it 'memoizes the value on set' do
    poro = Poro.new
    foo = Faker::Lorem.word
    bar = Faker::Lorem.word

    foo_val = AValueObject.new(foo: foo, bar: bar, baz_qux: nil)
    poro.foo = foo_val

    expect(poro.foo.object_id).to eq foo_val.object_id
  end

  it 'assigns an array of values' do
    poro = ArrayPoro.new
    foo = Faker::Lorem.word
    bar = Faker::Lorem.word
    foo_val = AValueObject.new(foo: foo, bar: bar, baz_qux: nil)
    poro.foo = [foo_val]

    expect(poro.foo[0]).to eq foo_val
  end

  it 'validates using AM validations' do
    poro = ValidateablePoro.new
    poro.foo = AValidatedObject.new
    poro.foos = [AValidatedObject.new]

    expect(poro.validate).to be false
    expect(poro.errors.map(&:attribute)).to include(:'foo/foo', :'foos/0/foo')

    poro.foo = AValidatedObject.new(foo: 'hi')
    poro.foos = [AValidatedObject.new(foo: 'hi')]

    expect(poro.validate).to be true
  end
end
