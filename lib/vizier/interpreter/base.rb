require 'logger'
require 'vizier/formatter/progress'
require 'vizier/formatter/view'
require 'vizier/results'
require 'vizier/visit-states/command-setup'

module Vizier
  #This is the base interpreter class.  By itself it'll raise a bunch of
  #NoMethodErrors.
  #
  #Interpreters manage the Subject object(s) and CommandSet and process
  #input.
  #
  #Subclasses of BaseInterpreter (like TextInterpreter, for
  #instance, must implement #cook_input(raw) that converts raw input (of
  #whatever form is appropriate to the interpreter) into CommandSetup
  #objects.  Other methods can be overridden - especially consider
  # #get_formatter, and #prompt_user
  class BaseInterpreter
    include Visitors::Client

    attr_accessor :out_io, :logger, :renderer
    attr_reader :command_set, :engine

    def initialize(command_set, engine)
      @engine = engine
      @command_set = command_set
      @sub_modes = []
      @behavior = {
        :screen_width => 76,
        :warn_no_undo => true
      }
      @out_io = $stdout
      @stop = false
      @logger = Logger.new($stderr)
      @logger.level=Logger::FATAL
    end

    def renderer
      @renderer ||= default_renderer
    end

    def default_renderer
      require 'vizier/renderers/base'
      Renderers::Base.new
    end

    def command_set=(set)
      set = set.described if CommandDescription === set
      @command_set = set
    end

    #Any options that the interpreter might have can be set by passing a
    #hash to behavior to be merged with the defaults
    def behavior(hash)
      @behavior.merge!(hash)
    end

    #Present +message+ to the user, and get a response - usually yes or no.
    #Non-interactive interpreters, or ones where that level of interaction
    #is undesirable should not override this method, which returns "no".
    #
    #XXX: should non-interactive interpreters return an exception?
    def prompt_user(message)
      "no"
    end

    def register_formatters(presenter)
    end

    def input_pending?
      false
    end

    def normalized_input(raw_input)
      cook_input(raw_input)
    end

    #Process a single unit of input from the user.  Relies on cook input to
    #convert +raw_input+ into a CommandSetup
    def process_input(raw_input)
      @engine.inject_command(normalized_input(raw_input), self)
      @engine.execute_pending_commands
    end

    def get_view_formatter
      return Results::ViewFormatter.new
    end

    def output_format
      "text"
    end

    def output_result(command, result)
      text = renderer.render(command, result)
      ::Vizier::raw_stdout.puts(text) unless text.empty?
    end

    def command_visit(visitor, state_class, input)
      @engine.command_visit(visitor, state_class, input)
    end

    def current_command_set
      @command_set
    end
  end
end
