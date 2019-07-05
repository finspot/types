# Types

Ruby type coercion and structure library

## Types casting

```ruby
# Default usage
Types.cast(3, type: :int)
# => 3

Types.cast("foo", type: :int)
# => <Types::CastError could not cast "foo" into integer>

# Short-hand notation
Types.cast(3, :int)
# => 3
```

## Options

### Nullable types anbd default values
```ruby
Types.cast(nil, type: :int)
# => <Types::CastError unexpected nil>

Types.cast(nil, type: :int, nullable: true)
# => nil

Types.cast(nil, type: :int, default: 0)
# => 0
```

## Built-in types

| Types        | Definition                  | Definition                            |
|-------------|-----------------------------|---------------------------------------|
| `:int`      | Integer                     |                                       |
| `:float`    | Float                       |                                       |
| `:string`   | String                      |                                       |
| `:date`     | Date                        |                                       |
| `:datetime` | DateTime                    |                                       |
| `:enum`     | Symbol in a list            | `{type: :enum, values: [:foo, :bar]}` |
| `:bool`     | Boolean                     |                                       |
| `:array`    | Collection of a single type | `{type: :array, of: :int}`            |

## Objects

```ruby
Types.cast(localisation, type: :object, fields: {
    city: :string,
    country: {type: :enum, values: [:fr, :de, :uk]},
    street: :string,
    zipcode: :string
})
```

## Structure generation (from object type definition)
```ruby
User = Types::Struct.new(
    first_name: :string,
    last_name: :string
) do
    def name
        "#{first_name} #{last_name}"
    end
end

u = User.new(first_name: "John", last_name: "Doe")
u.name
# => "John Doe"

u = User.new(name: "John")
# => <Types::Error>
```

## Nestable types
```ruby
Income = Types::Struct.new(
    amount: :float,
    taxes: { type: :enum, values: [:before, :after], default: :after },
    period: { type: :enum, values: [:monthly, :yearly] }
) do
    def full_amount
        amount * (period == :monthly ? 12 : 1) * (taxes == :before ? 0.78 : 1)
    end
end

Mortgagor = Types::Struct.new(
    name: :string,
    age: :int,
    job: {
        type: :object,
        nullable: true,
        fields: {
            employer: :string,
            address: :localisation
        }
    },
    incomes: { 
        type: :array, 
        of: Income
    }
)

m = Mortgagor.new(name: "John", age: 12, incomes: [{ amount: 2500, period: :monthly }])
m.incomes.sum(&:full_amount)
# => 30000
```

## Custom type definition
```ruby
# Custom casting logic
Types.register(:percent) do |val, _opts|
    fail "Expected number" unless val.is_a? Numeric
    fail "Cannot be lower than 0" if val < 0
    fail "Cannot be higher than 1" if val > 1
    val.to_f
end

# Custom with parameters ? (reimplement enum, or array)
# Or just implement it then call it
Types.register(:enum) do |val, opts|
    opts[:values].include?(val) ? val : fail "Value not in enum"
end
```


