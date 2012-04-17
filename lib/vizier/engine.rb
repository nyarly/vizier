module Vizier
  class Engine
    def initialize(command_set)
      self.command_set = command_set

      @commands_pending = []
      @undo_stack = UndoStack.new
      @pause_decks = Hash.new {|h,k| h[k]=[]}
    end

    #Before running an interpreter on input, you must set the subject.
    #Get a subject object by calling subject_template, assign it's fields,
    #and then pass it into subject=
    def subject= (subject)
      prep_subject(subject)

      subject.verify
      @subject = subject
    end

    def build_subject
      if @subject.nil?
        self.subject=(subject_template())
      end
      return @subject
    end
    #:section: Extension related methods

    #If your interpreter needs extra fields in the subject, alter
    #subject_requirements to return an array of those fields.
    def subject_requirements
      return [:undo_stack, :command_set,
        :chain_of_command, :pause_decks, :mode_stack]
    end

    def get_subject
      return Subject.new
    end

    def subject_template
      prep_subject(get_subject)
    end

    def command_set=(set)
      set = set.described if CommandDescription === set
      @command_set = set
      @subject = prep_subject(get_subject)
    end

    def current_command_set #This needs to be examined
      @command_set
    end

    def fill_subject
      template = self.subject
      yield template
      self.subject=(template)
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

    def default_arg_hash
      {}
    end

    def current_nesting
      []
    end

    #XXX Add defaults needs to be finished

    #TODO: This wants to migrate to Engine, where it should be tightly bound.
    #
    #Furthermore: interpeter becomes engine (maybe - or a "time to quit")
    #Because the undo_stack, pending_commands and pause decks should all
    #be part of the Engine.
    #
    #Possibly, there should be a command interface to the engine that's the
    #only thing that goes into the subject
    #
    #Finally, consider pending_commands fusing with the undo_stack
    #
    #And CommandSetups should have the facility to be reduced to basic types

    #This method sets up the fields in the subject required by the
    #interpreter.
    def prep_subject(subject)
      add_command_requirements(subject)
      @command_set.add_defaults(subject)
      subject.required_fields(subject_requirements())
      subject.undo_stack = @undo_stack
      subject.command_set = @command_set
      subject.chain_of_command = @commands_pending
      subject.pause_decks = @pause_decks
      subject.mode_stack = @sub_modes
      return subject
    end

    def executable_for(interpreter, setup)
      setup.arg_hash = default_arg_hash.merge(setup.arg_hash)
      setup.set_nesting = current_nesting + setup.set_nesting
      #Needs to fold in the interpreter into the subject
      return setup.command_instance(current_command_set, @subject)
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

    def inject_command(command_setup, interpreter)
      command_setup = VisitStates::CommandSetup.canonicalize(command_setup)
      @commands_pending.push [interpreter, command_setup]
    end

    def execute_one_command(presenter, interpreter, command_setup)
      cmd = executable_for(interpreter, command_setup)

      interpreter.register_formatters(presenter)

      #XXX: Two thoughts: this belongs in process_input or
      #EUs should have their 'input' associated with them.
      unless cmd.undoable?
        confirm = interpreter.prompt_user("That command cannot be undone.  Continue? ")
        if not ["yes", "y", "sure", "i suppose", "okay"].include? confirm.strip.downcase
          return
        end
      end
      begin
        wrapped_stdout = true
        begin
          collector = presenter.create_collector
          $stdout.add_dispatcher(collector)
        rescue NoMethodError
          wrapped_stdout = false
        end

        cmd.go(collector)
        cmd.join_undo(@subject.undo_stack) #Exceptions?  Resume?

        view = cmd.view
        view["results"] = output_view if Hash === view
        interpreter.output_result(command_setup, view)

      rescue Interrupt
        puts "Command cancelled"
      rescue CommandException => ce
        ce.command = cmd
        raise
      rescue ResumeFrom => rf
        deck = rf.pause_deck
        @subject.pause_decks[deck].push cmd
        raise unless ResumeFromOnlyThis === rf
      ensure
        $stdout.remove_dispatcher(collector) if wrapped_stdout
      end
    end

    def execute_pending_commands
      return if @commands_pending.empty?
      presenter = Results::Presenter.new

      output = get_view_formatter
      presenter.register_formatter(output)

      begin
        until @commands_pending.empty?
          execute_one_command(presenter, *next_command)
        end
      rescue ResumeFrom => rf
        @subject.pause_decks[deck] += @commands_pending
      rescue CommandException => ce
        ce.raw_input = raw_input
        raise
      end
      presenter.done

      @commands_pending.clear
    end
  end
end
