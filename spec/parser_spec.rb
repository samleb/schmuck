require_relative "spec_helper"

RSpec.describe Schmuck::Parser do
  def acc(type, key, optional: false) = described_class::Accessor.new(type, key, optional)
  def agg(*accessors, optional: false) = described_class::Aggregate.new(accessors, optional)

  subject(:parsed) { described_class.parse(source) }

  describe "single accessors" do
    {
      ".foo"    => [:method,   "foo"],
      "[:foo]"  => [:symbol,   :foo],
      "['foo']" => [:string,   "foo"],
      '["foo"]' => [:string,   "foo"],
      "[42]"    => [:index,    42],
      "[foo]"   => [:property, "foo"],
      "[12ab]"  => [:property, "12ab"],
    }.each do |src, (type, key)|
      context "with #{src.inspect}" do
        let(:source) { src }

        it { is_expected.to eq [acc(type, key)] }
      end
    end
  end

  context "with ? in front of any accessor" do
    let(:source) { "?.a?[0]?*.b" }

    it do
      is_expected.to eq [
        acc(:method, "a", optional: true),
        acc(:index, 0, optional: true),
        agg(acc(:method, "b"), optional: true),
      ]
    end
  end

  context "with a chain" do
    let(:source) { ".users[0][:name]" }

    it { is_expected.to eq [acc(:method, "users"), acc(:index, 0), acc(:symbol, :name)] }
  end

  context "with a single aggregate" do
    let(:source) { ".users*.name" }

    it { is_expected.to eq [acc(:method, "users"), agg(acc(:method, "name"))] }
  end

  context "with a grouped aggregate" do
    let(:source) { "*(.address?[:city])[0]" }

    it do
      is_expected.to eq [
        agg(acc(:method, "address"), acc(:symbol, :city, optional: true)),
        acc(:index, 0),
      ]
    end
  end

  context "with nested aggregates" do
    let(:source) { ".a*(.b*(.c[0]).d)" }

    it do
      is_expected.to eq [
        acc(:method, "a"),
        agg(acc(:method, "b"), agg(acc(:method, "c"), acc(:index, 0)), acc(:method, "d")),
      ]
    end
  end

  context "with stacked stars" do
    let(:source) { "**.a" }

    it { is_expected.to eq [agg(agg(acc(:method, "a")))] }
    it { is_expected.to eq described_class.parse("*(*.a)") }
  end

  context "with a star binding to one expression only" do
    let(:source) { ".x*.y.z" }

    it { is_expected.to eq [acc(:method, "x"), agg(acc(:method, "y")), acc(:method, "z")] }
  end

  describe "errors" do
    {
      ""         => "expected '.', '[' or '*'",
      "foo"      => "expected '.', '[' or '*'",
      "."        => "expected identifier",
      "[:foo"    => 'expected "]"',
      "['foo\"]" => %q(expected "'"),
      "*()"      => "expected '.', '[' or '*'",
      "*(.a"     => "expected '.', '[' or '*'",
      "??.a"     => "expected '.', '[' or '*'",
      "*(*(.a)"  => "expected '.', '[' or '*'",   # unclosed inner group
    }.each do |src, message|
      context "with #{src.inspect}" do
        let(:source) { src }

        it { expect { parsed }.to raise_error(described_class::ParseError, /#{Regexp.escape(message)}/) }
      end
    end
  end
end