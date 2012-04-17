require 'vizier/interpreter/base'
require 'vizier/engine'
require 'vizier/command-description'
require 'valise'

module Vizier
  #This class exists mostly to make spec and unit test writing easier.
  #Because Commands need so much care and feeding on the back end, it can be
  #troublesome to write specs on them directly.  QuickInterpreter is designed
  #for programmatic access, and easy setup.
  #
  #Honestly, this is what behavior driven design should be about.
  #
  #Example usage:
  #
  #  @interpreter = QuickInterpreter::define_interpreter do #unique to QI
  #    command :test do
  #      subject.a_field << "one"
  #    end
  #  end
  #
  #  @subject = @interpreter.subject_template
  #  @subject.a_field = []
  #  @interpreter.subject = @subject
  #
  #  @interpreter.process_input(:test, "args")
  #  @subject.a_field.length  # => 1; note that normally you need to
  #         #+get_image+ to access fields of the subject
  #
  class QuickInterpreter < BaseInterpreter
    class << self
      #You can use this method to create a new interpreter with a command
      #set.  The block is passed to Vizier::define_commands, so you can use
      #DSL::CommandSetDefinition there.
      def define_interpreter(&block)
        command_set = Vizier::define_commands(&block)
        engine = Vizier::Engine.new(command_set)
        interpreter = new(command_set, engine)
        return interpreter
      end

      def template_dir
        "quick"
      end

      alias define_commands define_interpreter
    end

    def initialize(command_set, engine)
      @formatter_factory = proc {Results::TextFormatter.new(::Vizier::raw_stdout)}
      super
      @template_files = Valise::Set.new() #The idea being that we should always default
    end

    #Saves the block passed to create formatters with.  Cleaner a singleton
    #get_formatter definition.
    def make_formatter(&block)
      @formatter_factory = proc &block
    end

    def register_formatters(presenter)
      presenter.register_formatter(@formatter_factory.call)
    end

    #Always returns "yes" so that undo warnings can be ignored.
    def prompt_user(message)
      "yes"
    end

    #Passes the arguments to process_input directly to CommandSetup
    def cook_input(words)
      return command_visit(Visitors::InputParser, VisitStates::CommandSetup, words)
    end

    def complete_input(terms)
      resolver = Visitors::ResolveCompletion.new(build_subject)
      completing = command_visit(Visitors::FindCompleters, VisitStates::CommandArguments, terms)
      resolver.add_states(*completing)
      return resolver.resolve
    end

  end

end
