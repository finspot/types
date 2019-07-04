require 'spec_helper'

RSpec.describe Types do
  require 'date'

  describe '::cast' do
    TYPE_EXPECTATIONS = {
      int: { 2 => 2, 0 => 0, 1.5 => :error, '3' => :error },
      float: { 2.1 => 2.1, 1 => 1.0, '3.2' => :error },
      string: { 'foo' => 'foo', 2 => :error, [] => :error },
      bool: { true => true, false => false, 0 => :error },
      date: {
        '2019-05-01' => Date.new(2_019, 5, 1),
        Date.new(2_019, 5, 1) => Date.new(2_019, 5, 1),
        DateTime.new(2_019, 5, 1, 12, 45) => :error,
        '2019-05-01T12:45:00Z' => :error
      },
      datetime: {
        '2019-05-01' => DateTime.new(2_019, 5, 1, 0, 0),
        Date.new(2_019, 5, 1) => DateTime.new(2_019, 5, 1, 0, 0),
        DateTime.new(2_019, 5, 1, 12, 45) => DateTime.new(2_019, 5, 1, 12, 45),
        '2019-05-01T12:45:00+00:00' => DateTime.new(2_019, 5, 1, 12, 45)
      },
      { type: :enum, values: %i[foo bar] } => {
        foo: :foo, 'bar' => :bar, boo: :error
      }
    }

    TYPE_EXPECTATIONS.each do |type, expectations|
      expectations.each do |input, output|
        if output == :error
          it "expects #{type.inspect} to raise an error on casting #{
               input.inspect
             }" do
            expect { described_class.cast(input, type) }.to raise_error(
              Types::CastError
            )
          end
        else
          it "expects #{type.inspect} to cast #{input.inspect} to #{
               output.inspect
             }" do
            expect(described_class.cast(input, type)).to eq output
          end
        end
      end
    end

    subject { described_class.cast(input, type) }

    describe 'object' do
      let(:type) { { type: :object, fields: { int: :int, string: :string } } }

      let(:input) { { int: 2, string: 'string' } }

      context 'extra fields' do
        it { expect(subject).to eq input }
      end

      context 'missing fields' do
        let(:input) { { int: 2 } }
        it { expect { subject }.to raise_error(Types::CastError) }

        context 'when nullable' do
          let(:type) do
            {
              type: :object,
              fields: { int: :int, string: { type: :string, nullable: true } }
            }
          end
          it { expect(subject).to eq({ int: 2, string: nil }) }
        end
      end
    end

    describe 'array' do
      let(:type) { { type: :array, of: :int } }
      let(:input) { [1, 2, 3] }
      it { expect(subject).to eq input }

      context 'invalid fields' do
        let(:input) { [1, 2, 'string'] }
        it { expect { subject }.to raise_error(Types::CastError) }
      end
    end
  end

  describe '::alias' do
    before do
      Types.alias(:number, :float)
      Types.alias(
        :location,
        { type: :object, fields: { lat: :number, lng: :number } }
      )
    end

    it do
      expect(Types.cast(12, :number)).to eq 12.0
      expect(Types.cast({ lat: 12, lng: 13 }, :location)).to eq(
        lat: 12.0, lng: 13.0
      )
    end
  end

  describe '::register' do
    before do
      Types.register(:even_int) do |val, opts|
        Types.cast(val, :int)
        fail Types::CastError, 'Even numbers only' unless val.even?
        val
      end
    end

    it do
      expect(Types.cast(6, :even_int)).to eq 6
      expect { Types.cast(5, :even_int) }.to raise_error(Types::CastError)
      expect { Types.cast('foo', :even_int) }.to raise_error(Types::CastError)
    end
  end
end
