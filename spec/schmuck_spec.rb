require "spec_helper"

RSpec.describe Schmuck do
  it "has a version number" do
    expect(Schmuck::VERSION).not_to be nil
  end

  let(:hashes) {
    (1..5).map do |n|
      {
        integer: n,
        float: n.to_f,
        double: n * 2,
        square: n ** 2,
        multiples: [n * 2, n * 3, n * 4]
      }
    end
  }

  it "handles complex cases" do
    response = { results: hashes }
    
    output = response.then(&'[results]*([multiples][2]).max')
    expect(output).to eq(20)
    
    output = response.then(&'[results].first[:integer]')
    expect(output).to eq(1)

    expect(hashes.then(&'*([multiples][1]).max')).to eq(15)

    response = {
      results: [
        { weights: [ [0, 1, 2], [1, 2, 3], [2, 3, 4] ] },
        { weights: [ [3, 4, 5], [4, 5, 6], [5, 6, 7] ] },
      ]
    }
    expect(
      response.then(&'[results]*([weights][0]*.succ)')
    ).to eq([[1, 2, 3], [4, 5, 6]])
  end

  it "fails on nil unless the accessor is optional" do
    expect({ a: nil }.then(&'[a]?.b')).to be_nil
    expect { { a: nil }.then(&'[a].b') }.to raise_error(NoMethodError)
    expect { { a: nil }.then(&'[a]*.b') }.to raise_error(ArgumentError, "object isn't optional")
  end
end
