require "json"

RSpec.describe Schmuck do
  it "has a version number" do
    expect(Schmuck::VERSION).not_to be nil
  end

  context "with a paginated REST response" do
    let(:response) { JSON.parse(<<~JSON) }
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
    JSON

    it "groups a nested lookup per element" do
      expect(response.then(&'[data]*([customer][address][city])')).to eq(%w[Lyon Paris])
    end

    it "nests aggregates and post-processes the result" do
      expect(response.then(&'[data]*([items]*[sku]).flatten.uniq')).to eq(%w[BOOK-001 PEN-042])
      expect(response.then(&'[data]*([items]*[quantity]).flatten.sum')).to eq(4)
    end

    it "keeps the structure of nested arrays" do
      expect(response.then(&'[data]*([items]*([price][amount]))')).to eq([[1500, 300], [1500]])
    end
  end

  context "with a top-level array response" do
    let(:pull_requests) { JSON.parse(<<~JSON) }
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
    JSON

    it "starts with an aggregate" do
      expect(pull_requests.then(&'*([user][login])')).to eq(%w[octocat hubot])
      expect(pull_requests.then(&'*([labels]*[name])')).to eq([%w[enhancement parser], []])
    end

    it "calls predicate methods" do
      expect(pull_requests.then(&'*[draft]."any?"')).to be(true)
      expect(pull_requests.then(&'*([labels]."empty?")')).to eq([false, true])
    end

    it "skips null values with optional accessors" do
      expect(pull_requests.then(&'*([head][repo]?[full_name])')).to eq(["octocat/schmuck", nil])
    end
  end

  context "with a deeply nested GraphQL response" do
    let(:response) { JSON.parse(<<~JSON) }
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
    JSON

    it "digs through connections" do
      expect(response.then(&'[data][repository][issues][edges]*([node][title])'))
        .to eq(["Support negative indexes", "Document aggregates"])
    end

    it "digs through nested connections" do
      expect(response.then(&'[data][repository][issues][edges]*([node][labels][edges]*([node][name])).flatten'))
        .to eq(["parser", "good first issue", "docs"])
    end
  end

  it "fails on nil unless the accessor is optional" do
    expect({ a: nil }.then(&'[a]?.b')).to be_nil
    expect { { a: nil }.then(&'[a].b') }.to raise_error(NoMethodError)
    expect { { a: nil }.then(&'[a]*.b') }.to raise_error(ArgumentError, "object isn't optional")
  end
end
