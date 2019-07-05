require 'spec_helper'

RSpec.describe Types::Struct do
  let(:struct) do
    described_class.define(first_name: :string, last_name: :string) do
      def name
        "#{first_name} #{last_name}"
      end
    end
  end

  let(:input) { { first_name: 'John', last_name: 'Doe' } }

  subject { struct.new(input) }

  it do
    expect(subject.first_name).to eq 'John'
    expect(subject.last_name).to eq 'Doe'
    expect(subject.name).to eq 'John Doe'
    expect(struct.definition).to eq(
      first_name: { type: :string }, last_name: { type: :string }
    )
  end

  describe 'value equality' do
    it do
      a = struct.new(first_name: 'John', last_name: 'Doe')
      b = struct.new(first_name: 'John', last_name: 'Doe')
      expect(a == b).to be true
      expect(a.eql?(b)).to be true

      hash = { a => 1, b => 1}
      expect(hash.length).to eq 1
    end
  end

  describe 'without block' do
    let(:struct) do
      described_class.define(
        lat: { type: :float, default: 0 }, lng: { type: :float, default: 0 }
      )
    end

    let(:input) { { lat: 10 } }

    it do
      expect(subject.lat).to eq 10.0
      expect(subject.lng).to eq 0
    end
  end

  describe 'nested structs' do
    let(:struct) do
      described_class.define(
        foo: :string, bar: { type: :object, fields: { baz: :string } }
      )
    end

    let(:input) { { foo: 'foo', bar: { baz: 'baz' } } }

    it 'exposes a struct' do
      expect(subject.foo).to eq 'foo'
      expect(subject.bar.baz).to eq 'baz'
      expect(struct.new(foo: 'foo', bar: { baz: 'boo' }).bar.baz).to eq 'boo'
    end
  end

  describe 'reusing structs' do
    let(:child) do
      described_class.define(baz: :string) do
        def yell
          baz.upcase
        end
      end
    end
    let(:struct) { described_class.define(foo: :string, bar: child) }
    let(:input) { { foo: 'foo', bar: { baz: 'baz' } } }

    it 'exposes a struct' do
      expect(subject.foo).to eq 'foo'
      expect(subject.bar.baz).to eq 'baz'
      expect(subject.bar.yell).to eq 'BAZ'
    end
  end

  describe 'nested struct arrays' do
    let(:income_type) do
      {
        type: :object,
        fields: {
          amount: :float,
          period: { type: :enum, values: %i[monthly yearly], default: :monthly }
        }
      }
    end
    let(:struct) do
      described_class.define(incomes: { type: :array, of: income_type })
    end

    let(:input) do
      { incomes: [{ amount: 1_200 }, { amount: 20_000, period: :yearly }] }
    end

    it do
      expect(subject.incomes.first.amount).to eq 1_200
      expect(subject.to_h).to eq (
           {
             incomes: [
               { amount: 1_200, period: :monthly },
               { amount: 20_000, period: :yearly }
             ]
           }
         )
    end

    context 'with invalid payload' do
      let(:input) do
        {
          incomes: [
            { amount: 1_200, period: :daily },
            { amount: 20_000, period: :yearly }
          ]
        }
      end
      it 'raises an error' do
        expect { subject }.to raise_error(
          Types::CastError,
          'Could not cast element {:amount=>1200, :period=>:daily} : Value :daily not included in the enum [:monthly, :yearly]'
        )
      end
    end
  end
end
