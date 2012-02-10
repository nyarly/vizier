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
    attr_reader :subject, :command_set, :sub_modes

    def initialize
      @command_set=nil
      @sub_modes = []
      @behavior = {
        :screen_width => 76,
        :warn_no_undo => true
      }
      @out_io = $stdout
      @stop = false
      @subject = nil
      @logger = Logger.new($stderr)
      @logger.level=Logger::FATAL
      @undo_stack = UndoStack.new
      @commands_pending = []
      @pause_decks = Hash.new {|h,k| h[k]=[]}
    end

    #:section: Client app methods
    alias subject_template subject

    #Before running an interpreter on input, you must set the subject.
    #Get a subject object by calling subject_template, assign it's fields,
    #and then pass it into subject=
    def subject= (subject)
      subject
      begin
        subject.get_image(subject_requirements())
      rescue CommandException
        prep_subject(subject)
      end

      subject.verify
      @subject = subject
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
      @subject = prep_subject(get_subject)
    end

    def fill_subject
      template = self.subject
      yield template
      self.subject=(template)
    end

    #Any options that the interpreter might have can be set by passing a
    #hash to behavior to be merged with the defaults
    def behavior(hash)
      @behavior.merge!(hash)
    end

    #:section: Command behavior related method


    #  Puts a CommandSet ahead of the current one for processing.  Useful for command
    #  modes, like Cisco's IOS with configure modes, et al.
    def push_mode(mode, root_command)
      #TODO: store a command setup to use as the root of future searches
      unless Command === mode
        raise RuntimeError, "Sub-modes must be Commands!"
      end

      sub_modes.push([mode, root_command])
      return nil
    end

    #  The compliment to #push_mode.  Removes the most recent command set.
    def pop_mode
      sub_modes.pop
      return nil
    end

    #:section: Extension related methods

    #If your interpreter needs extra fields in the subject, alter
    #subject_requirements to return an array of those fields.
    def subject_requirements
      return [:undo_stack, :command_set, :interpreter, :interpreter_behavior,
        :chain_of_command, :pause_decks, :mode_stack]
    end

    def get_subject
      return Subject.new
    end

    #XXX Add defaults needs to be finished

    #This method sets up the fields in the subject required by the
    #interpreter.
    def prep_subject(subject)
      add_command_requirements(subject)
      @command_set.add_defaults(subject)
      subject.required_fields(subject_requirements())
      subject.undo_stack = @undo_stack
      subject.command_set = @command_set
      subject.interpreter = self
      subject.interpreter_behavior = @behavior
      subject.chain_of_command = @commands_pending
      subject.pause_decks = @pause_decks
      subject.mode_stack = @sub_modes
      return subject
    end

    def add_command_requirements(subject)
      collector = Visitors::RequirementsCollector.new(subject)
      collector.add_state(VisitStates::VisitState.new(@command_set))
      collector.resolve
    end

    #Gets the next command in the queue - related to DSL::Action#chain.
    #You'll almost never want to override this method.
    def next_command
      @commands_pending.shift
    end

    def executable_for(setup)
      setup.arg_hash = default_arg_hash.merge(setup.arg_hash)
      setup.set_nesting = current_nesting + setup.set_nesting
      return setup.command_instance(current_command_set, build_subject)
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

    def command_visit(visitor_class, state_class, input)
      visitor = visitor_class.new(build_subject)
      visitor.add_states(state_class.new(current_command_set, input))
      if block_given?
        return yield(visitor)
      else
        return visitor.resolve
      end
    end

    def begin_processing(raw_input)
      @commands_pending.unshift(executable_for(cook_input(raw_input)))
    end

    def input_pending?
      false
    end

    def inject_command(path, arg_hash)
      node = command_visit(Visitors::Command, VisitStates::CommandPathState, path)

      command = Visitors::CommandSetup.new(node)
      command.arg_hash = arg_hash

      if input_pending?
        @pause_decks[:after] << command
      else
        @commands_pending << command
        execute_pending_commands(nil)
      end
    end

    #Process a single unit of input from the user.  Relies on cook input to
    #convert +raw_input+ into a CommandSetup
    def process_input(raw_input)
      begin_processing(raw_input)

      execute_pending_commands(raw_input)
      unless @pause_decks[:after].empty?
        @commands_pending += @pause_decks[:after]
        @pause_decks[:after].clear
        execute_pending_commands(nil)
      end
    end

    def execute_one_command(raw_input, output)
      cmd = next_command

      #XXX: Two thoughts: this belongs in process_input or
      #EUs should have their 'input' associated with them.
      if ( not raw_input.nil? and @behavior[:warn_no_undo] and not cmd.undoable? )
        confirm = prompt_user("\"#{raw_input}\" cannot be undone.  Continue? ")
        if not ["yes", "y", "sure", "i suppose", "okay"].include? confirm.strip.downcase
          return
        end
      end
      begin
        #XXX rebuild or remove collector
        execute(cmd, nil)
        cmd.join_undo(@undo_stack) #Exceptions?  Resume?
        output_result(render_output(cmd, output.view))
      rescue Interrupt
        puts "Command cancelled"
      rescue CommandException => ce
        ce.command = cmd
        raise
      rescue ResumeFrom => rf
        deck = rf.pause_deck
        @pause_decks[deck].push cmd
        raise unless ResumeFromOnlyThis === rf
      end
    end

    def execute_pending_commands(raw_input)
      presenter = Results::Presenter.new

      output = get_view_formatter
      presenter.register_formatter(output)

      register_formatters(presenter)

      collector = presenter.create_collector

      begin
        wrapped_stdout = true
        begin
          $stdout.add_dispatcher(collector)
        rescue NoMethodError
          wrapped_stdout = false
        end


        until @commands_pending.empty?
          execute_one_command(raw_input, output)
        end
      rescue ResumeFrom => rf
        @pause_decks[deck] += @commands_pending
      rescue CommandException => ce
        ce.raw_input = raw_input
        raise
      ensure
        $stdout.remove_dispatcher(collector) if wrapped_stdout
      end
      presenter.done

      @commands_pending.clear
    end

    def get_view_formatter
      return Results::ViewFormatter.new
    end

    def output_format
      "text"
    end

    def render_output(command, output_view)
      view = command.view
      view["results"] = output_view if Hash === view
      renderer.render(command, view)
    end

    def output_result(result)
      ::Vizier::raw_stdout.puts(result) unless result.empty?
    end

    protected

    def execute(command, collector)
      command.go(collector)
      return nil
    end

    def default_arg_hash
      return {} if @sub_modes.empty?
      return @sub_modes.last[1].arg_hash
    end

    def current_command_set
      return @command_set if @sub_modes.empty?
      return @sub_modes.last[0]
    end

    def current_nesting
      return [] if @sub_modes.empty?
      return @sub_modes.map{|item| item[1]}
    end

    def build_subject
      if @subject.nil?
        self.subject=(subject_template())
      end
      return @subject
    end
  end
end
