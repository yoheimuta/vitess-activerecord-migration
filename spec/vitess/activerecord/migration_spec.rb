# frozen_string_literal: true

RSpec.describe Vitess::Activerecord::Migration do
  it "has a version number" do
    expect(Vitess::Activerecord::Migration::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
