require "vizier"
require "valise"

describe Vizier::Command, "setting up a Valise", :type => :command_set do
  command_set do
    command :templated do
      template_for(:text, <<-EOT)
        <<<
        I'm a template
      EOT
    end
  end

  before do
    @valise = Valise::DefinedDefaults.new
    command_set.default_files(@valise)
  end

  it "should create a template" do
    @valise.find(%w{text templates templated}).contents.should == "I'm a template"
  end
end
