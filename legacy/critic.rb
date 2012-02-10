require 'spec/matchers'
require 'spec/example'
require 'spec/extensions'
require 'spec/runner'

describe "A well written command", :shared => true do
  it "should have useful documentation" do
    @command.documentation(70).length.should be > @command.short_docs(70).length
  end

  it "should have a classy response to undo" do
    unless @command.allocate.undoable?
      pending "#{@command.name} handling undo"
    end
  end
end

describe "A well written command set", :shared => true do
  it "should include quit" do
    @set.command_names.should include("quit")
  end

  it "should include help" do
    @set.command_names.should include("help")
  end
end

module Vizier
  require 'rake'
  require 'spec/rake/spectask'
  class CritiqueLoader < ::Spec::Runner::ExampleGroupRunner
    def initialize(opts, command_set)
      super(opts)
      @command_set_module = command_set
    end

    def load_files(files)
      set = CommandSet::new
      set.require_commands(@command_set_module)
      Critic.criticize(set)
    end
  end

  module Critic
    def self.criticize(set, path = ["Main"])
      Kernel::describe "Command set: #{path.join(" ")}" do
        it_should_behave_like "A well written command set"
        before do
          @set = set
        end
      end

      set.command_list.each_pair do |name, cmd|
        if CommandSet === cmd
          Vizier::Spec::Critic.criticize(cmd, path + [name])
        else
          Kernel::describe "Command: #{path.join(" ")} #{name}" do
            it_should_behave_like "A well written command"
            before do
              @command = cmd
            end
          end
        end
      end
    end

    class Task < ::Rake::TaskLib
      def initialize(name = :critique)
        @name = name
        @spec_opts = []
        @ruby_opts = []

        @command_set_file = nil
        @command_set_module = nil
        yield self if block_given?
        define
      end

      attr_accessor :spec_opts, :command_set_file, :command_set_module, :ruby_opts

      def define
        spec_opts = @spec_opts
        unless spec_opts.include?("-f") or spec_opts.include?("--format")
          spec_opts += %w{--format specdoc}
        end

        spec_opts = @spec_opts + ["-r", @command_set_file,
        "-r", __FILE__,
        "-U", "Vizier::CritiqueLoader:" + @command_set_module,
        "--color"] #Because color is nice...

        csf = @command_set_file

        desc "Critique the command set defined in #@command_set_module"
        Spec::Rake::SpecTask.new(@name) do |t|
          t.spec_opts = spec_opts
          t.ruby_opts = self.ruby_opts
          t.spec_files = [csf]
        end
      end
    end
  end
end
