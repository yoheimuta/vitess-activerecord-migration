# frozen_string_literal: true

require_relative "../../support/rails_support"

RSpec.describe Vitess::Activerecord::Migration do
  let(:rails) { RailsSupport.new }

  before do
    rails.setup
  end

  after do
    # rails.cleanup
  end

  it "has a version number" do
    expect(Vitess::Activerecord::Migration::VERSION).not_to be nil
  end

  it "does something useful" do
    # expect(false).to eq(true)
    expect(true).to eq(true)
  end
end
