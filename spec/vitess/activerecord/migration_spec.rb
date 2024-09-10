# frozen_string_literal: true

require_relative "../../support/rails_support"

RSpec.describe Vitess::Activerecord::Migration do
  it "has a version number" do
    expect(Vitess::Activerecord::Migration::VERSION).not_to be nil
  end

  describe "exec_migration" do
    let(:rails) { RailsSupport.new }

    before do
      rails.setup
    end

    after do
      rails.cleanup
    end

  end
end
