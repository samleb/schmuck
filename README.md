# Schmuck

[![Test](https://github.com/samleb/schmuck/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/samleb/schmuck/actions/workflows/test.yml?query=branch%3Amaster)

Readable paths through nested hashes and arrays, usable as blocks.

## Installation

Schmuck isn't released on RubyGems.org yet. Install it from GitHub and add it to
the application's Gemfile by executing:

```bash
bundle add schmuck --git https://github.com/samleb/schmuck
```

## Usage

Parsed JSON is made of hashes inside arrays inside hashes. In plain Ruby, every
array level needs another `map` with another block and another variable name,
and the path you care about gets lost in them.

Schmuck adds `String#to_proc`: you write the path as a string and pass it as a
block, to `then` or to any method that takes a block:

```ruby
response.then(&'[data]*([customer][address][city])')
pull_requests.map(&'[user][login]')
```

| Syntax                  | Meaning                                              | Ruby                          |
|-------------------------|------------------------------------------------------|-------------------------------|
| `.name`                 | method call                                          | `object.name`                 |
| `."any?"`, `.'any?'`    | method whose name needs quoting (`?`, `!`, …)        | `object.any?`                 |
| `[name]`                | hash key, as a string, then as a symbol              | `hash["name"]`, `hash[:name]` |
| `["a key"]`, `['a key']`| string key, any characters                           | `hash["a key"]`               |
| `[:name]`               | symbol key                                           | `hash[:name]`                 |
| `[0]`                   | index                                                | `array[0]`                    |
| `*x`, `*(x y …)`        | map the next accessor (or group) over each element   | `array.map { … }`             |
| `?x`                    | skip the accessor when its receiver is `nil`         | `&.`                          |

Without `?`, an accessor called on `nil` raises, just like plain Ruby. `*`
applies to the next accessor only, so `*[a][b]` maps `[a]` and then calls
`[b]` on the resulting array: use `*([a][b])` to apply both to each element.

### A paginated REST response

```json
{
  "data": [
    {
      "id": "ord_1001",
      "customer": { "name": "Alice Martin", "address": { "city": "Lyon", "country": "FR" } },
      "items": [
        { "sku": "BOOK-001", "quantity": 2, "price": { "amount": 1500, "currency": "EUR" } },
        { "sku": "PEN-042", "quantity": 1, "price": { "amount": 300, "currency": "EUR" } }
      ]
    },
    {
      "id": "ord_1002",
      "customer": { "name": "Bob Durand", "address": { "city": "Paris", "country": "FR" } },
      "items": [
        { "sku": "BOOK-001", "quantity": 1, "price": { "amount": 1500, "currency": "EUR" } }
      ]
    }
  ],
  "meta": { "page": 1, "per_page": 2, "total": 2 }
}
```

Plain Ruby:

```ruby
response["data"].map { |order| order.dig("customer", "address", "city") }
response["data"].flat_map { |order| order["items"].map { |item| item["sku"] } }.uniq
response["data"].sum { |order| order["items"].sum { |item| item["quantity"] } }
```

Schmuck:

```ruby
response.then(&'[data]*([customer][address][city])')     # => ["Lyon", "Paris"]
response.then(&'[data]*([items]*[sku]).flatten.uniq')     # => ["BOOK-001", "PEN-042"]
response.then(&'[data]*([items]*[quantity]).flatten.sum') # => 4
```

### A top-level array response

```json
[
  {
    "number": 42,
    "draft": false,
    "user": { "login": "octocat" },
    "labels": [{ "name": "enhancement" }, { "name": "parser" }],
    "head": { "ref": "optional-accessors", "repo": { "full_name": "octocat/schmuck" } }
  },
  {
    "number": 43,
    "draft": true,
    "user": { "login": "hubot" },
    "labels": [],
    "head": { "ref": "patch-1", "repo": null }
  }
]
```

Plain Ruby:

```ruby
pull_requests.map { |pr| pr.dig("user", "login") }
pull_requests.map { |pr| pr["labels"].map { |label| label["name"] } }
pull_requests.any? { |pr| pr["draft"] }
pull_requests.map { |pr| pr["head"]["repo"]&.fetch("full_name") }
```

Schmuck:

```ruby
pull_requests.then(&'*([user][login])')            # => ["octocat", "hubot"]
pull_requests.then(&'*([labels]*[name])')          # => [["enhancement", "parser"], []]
pull_requests.then(&'*[draft]."any?"')             # => true
pull_requests.then(&'*([head][repo]?[full_name])') # => ["octocat/schmuck", nil]
```

### A deeply nested GraphQL response

```json
{
  "data": {
    "repository": {
      "issues": {
        "totalCount": 2,
        "edges": [
          {
            "node": {
              "title": "Support negative indexes",
              "labels": { "edges": [{ "node": { "name": "parser" } }, { "node": { "name": "good first issue" } }] }
            }
          },
          {
            "node": {
              "title": "Document aggregates",
              "labels": { "edges": [{ "node": { "name": "docs" } }] }
            }
          }
        ]
      }
    }
  }
}
```

Plain Ruby:

```ruby
response.dig("data", "repository", "issues", "edges").map { |edge| edge.dig("node", "title") }
response.dig("data", "repository", "issues", "edges").flat_map do |edge|
  edge.dig("node", "labels", "edges").map { |label| label.dig("node", "name") }
end
```

Schmuck:

```ruby
response.then(&'[data][repository][issues][edges]*([node][title])')
# => ["Support negative indexes", "Document aggregates"]
response.then(&'[data][repository][issues][edges]*([node][labels][edges]*([node][name])).flatten')
# => ["parser", "good first issue", "docs"]
```

## What sets schmuck apart from other JSON query languages

Here are the unique SKUs of the [REST example](#a-paginated-rest-response) in
the best-known JSON query languages:

| Language | Query                                                  |
|----------|--------------------------------------------------------|
| Schmuck  | `[data]*([items]*[sku]).flatten.uniq`                  |
| jq       | `[.data[].items[].sku] \| unique`                      |
| JSONPath | `$.data[*].items[*].sku` (no way to remove duplicates) |
| JMESPath | `data[].items[].sku` (no way to remove duplicates)     |
| JSONata  | `$distinct(data.items.sku)`                            |

- **It's plain Ruby.** A path is a block, so it works with `map`, `select`,
  `sort_by`, `then` or any other method that takes one. It runs on the objects
  you already have and returns Ruby objects: there is no JSON to serialize and
  parse again, and no native library to install (Ruby gems for jq wrap its C
  library).
- **Any Ruby method can appear in a path.** `.flatten.uniq`, `.sum` or
  `."any?"` replace the fixed set of functions that query languages provide.
- **Nested arrays keep their structure** until you call `.flatten`, while jq,
  JSONPath and JSONata flatten results automatically.
- **It's strict by default.** Accessing anything on `nil` raises unless you
  write `?`, where query languages usually return nothing.
- **The syntax feels familiar.** It extends Ruby's `Symbol#to_proc`
  (`map(&:name)`) to strings, and borrows Groovy's spread operator (`*.`) and
  JavaScript's optional chaining (`?.`).

The trade-off is that a path is a string parsed at runtime (and cached), so a
mistake in it only shows up when that code runs, and editors can't check or
autocomplete it.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/samleb/schmuck. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/samleb/schmuck/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Schmuck project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/samleb/schmuck/blob/master/CODE_OF_CONDUCT.md).
