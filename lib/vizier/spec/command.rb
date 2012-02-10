require 'vizier/subject'
require 'vizier/formatter/base'
require 'vizier/dsl'
require 'stencil/spec/view_matcher'

class RSpecFormatter < Vizier::Results::Formatter
  def initialize(io)
    @output = []
    super()
  end

  attr_reader :output

  def closed_begin_list(list)
    @output << list
  end

  def closed_item(item)
    ::Vizier::raw_stdout.print item
    @output << item
  end
end

Struct.new("SpecExecutionContext", :subject, :subject_context, :command_path, :set_nesting)


module Vizier
  module RSpec
    module ArgumentExampleGroup
      module InstanceMethods
        def embed_argument(argument)
          arguments[argument.name] = argument
        end

        def argument(name)
          arguments[name.to_s]
        end
      end

      def self.included(base)
        base.instance_eval do
          include Vizier::DSL::Argument
          include InstanceMethods
          let(:arguments) { {} }
        end
      end
    end

    module CommandSetExampleGroup

      module ClassMethods
        def command_set(&block)
          let(:command_set) { Vizier::define_commands(&block).described }
        end

      def subject(hash)
        before do
          setup_subject(command_set, hash)
        end
      end

      end

      module InstanceMethods
        SubjectDefaults = {
          "chain_of_command" => []
        }

        def setup_subject(cmd, subject_params={})
          cmd.add_requirements(vizier_subject)

          vizier_subject.required_fields([:command_set, :undo_stack, :chain_of_command])
          subject_params = { :command_set => cmd,
            :undo_stack => undo_stack }.merge(subject_params)
          SubjectDefaults.merge(subject_params).each_pair do |key, value|
            if Proc === value
              value = value.call
            else
              value = value.dup rescue value
            end

            vizier_subject.__send__(key.to_s + "=", value)
          end
        end

        def results
          formatter.output
        end

        def view
          @command.view
        end

        def process(input)
          raise "Ack!  No OutputStandin in place!" unless $stdout.respond_to?(:add_dispatcher)
          begin
            $stdout.add_dispatcher(results_collector)
            setup = command_set.process_terms(input, vizier_subject)
            setup.arg_hash = mode_arg_hash.merge(setup.arg_hash)
            setup.set_nesting = nesting + setup.set_nesting
            @command = setup.command_instance(command_set, vizier_subject)

            unless @command.class.executeable?
              raise CommandException, "incomplete command"
            end
            @command.go(results_collector)
          rescue ResumeFrom => rf
            deck = rf.pause_deck
            pause_decks[deck].push rf.setup
            raise unless ResumeFromOnlyThis === rf
          ensure
            $stdout.remove_dispatcher(results_collector)
          end
          return @command
        end

        def complete(input)
          return command_set.completion_list(input, vizier_subject)
        end
      end

      def self.included(base)
        base.instance_eval do
          extend ClassMethods
          include InstanceMethods
          include Stencil::ViewMatcher
          let(:formatter) { RSpecFormatter.new(::Vizier::raw_stdout) }
          let(:vizier_subject) { Subject.new }
          let(:execution_context) { Struct::SpecExecutionContext.new(vizier_subject, [], [], []) }
          let(:results_presenter) {
            presenter = Results::Presenter.new
            presenter.register_formatter(formatter)
            presenter
          }
          let(:results_collector) { results_presenter.create_collector }
          let(:undo_stack) { UndoStack.new }
          let(:mode_arg_hash) { {} }
          let(:nesting) { [] }
          let(:pause_decks) { {} }
        end
      end
    end

    module CommandExampleGroup

      module ClassMethods
        def command(name, &block)
          let(:command) { Command::setup(name, &block) }
          let(:command_set) { the_cmd = self.command; Vizier::define_commands { command the_cmd } }
        end

        def arguments(hash)
          let(:invocation) { execute_command(command, hash) }
        end
      end

      module InstanceMethods
        def execute_command(cmd, hash={})
          raise "Ack!  No OutputStandin in place!" unless $stdout.respond_to?(:add_dispatcher)
          begin
            $stdout.add_dispatcher(results_collector)
            instance = cmd.new(execution_context)
            instance.consume_hash(hash)
            instance.go(results_collector)
          ensure
            $stdout.remove_dispatcher(results_collector)
          end
          return instance
        end
      end

      def self.included(base)
        base.instance_eval do
          include CommandSetExampleGroup
          extend ClassMethods
          include InstanceMethods
        end
      end
    end
  end
end

RSpec::configure do |conf|
  conf.include Vizier::RSpec::CommandExampleGroup, :type => :command, :example_group => {
    :file_path => %r{#{File::join("spec", "command", "")}}
  }
  conf.include Vizier::RSpec::CommandSetExampleGroup, :type => :command_set, :example_group => {
    :file_path => %r{#{File::join("spec", "command_set", "")}}
  }
  conf.include Vizier::RSpec::ArgumentExampleGroup, :type => :argument, :example_group => {
    :file_path => %r{#{File::join("spec", "argument", "")}}
  }
end
