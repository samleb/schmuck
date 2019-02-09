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

  it "does something useful" do
    expect(
      hashes.map(&'[multiples][1]')
    ).to eq([3, 6, 9, 12, 15])
  end
end
