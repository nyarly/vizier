module Vizier
  module DSL

    #The methods available within the DSL::CommandDefinition#action method
    #
    #Also note that you can access the arguments of a command as read-only
    #attributes, and you can write to and read from instance variables,
    #which will be local to the invocation of the command.  This is
    #especially useful for undo and redo.
    module Action
      include Formatting

      #:section: Basics

      #Some commands sometimes cause side effects.  When evaluating
      #arguments, if you discover that undoing doesn't make sense, and will
      #be confusing to the user, call dont_undo, and the interpreter will
      #ignore the call for purposes of undoing
      def dont_undo
        @should_undo = false
        return nil
      end

      #This is how you'll access the Vizier::Subject object that's the
      #interface of every command to the program state.
      def subject
        @subject
      end

      #:section: Pause and Resume

      #Stop here.  Return control to the user.  If several commands are
      #chained (c.f. #chain) and the pause is subsequently resumed
      #(StandardCommands::Resume) the whole chain will be resumed.
      def pause(deck = nil)
        raise ResumeFrom, deck
      end

      #Stop here and return control to the user.  If several commands are
      #chained (c.f. #chain) and the pause is subsequently resumed
      #(StandardCommands::Resume) the rest of the chain (not this command)
      #will be dropped.
      def defer(deck = nil)
        raise ResumeFromOnlyThis, deck
      end

      #Allows for a command to be broken into pieces so that a resume can
      #pick up within a command.  The block will be executed normally, but
      #if the command is resumed with a task id, all task blocks until that
      #id will be skipped.
      def task(id) #:yield:
        if not @resume_from.nil?
          if @resume_from == id
            @resume_from = nil
          end
          return
        end
        yield if block_given?
        @last_completed_task = id
      end

=begin
I think that, with the switch to topo-graph Tasklists, this might be superfluous
The one scenario I can see is conditional lists - "If this, then these tasks..." But I'm not sure when that would happen yet.


      #:section: Command compositing

      #It frequently makes sense to offer shortcut chains to the user, or
      #even commands that can only be run as part of another command.
      #Calling chain with either a command class or a command path allows
      #will cause that command to be invoked before returning control to the
      #user.
      def chain(*args)
        anchor = @nesting[-2]
        setup = Visitors::AnchoredCommandSetup.new(anchor)
        setup.arg_hash = Hash === args.last ? args.pop : {}

        if args.length == 1
          args = args[0]
          case args
          when Array
            setup.command_path = args
          when String
            setup.command_path = [args]
          when Symbol
            setup.command_path = [args.to_s]
          when Class
            setup.node = args
          else
            raise CommandException, "Can't chain #{args.inspect}"
          end
        else
          if args.find{|arg| not (String === arg or Symbol === arg)}
            raise CommandException, "Can't chain #{args.inspect}"
          else
            setup.terms = args.map{|arg| arg.to_s}
          end
        end

        subject.chain_of_command.push(setup)
      end

      #Like #chain, but interjects the command being chained to the start of
      #the queue, immediately after this command completes.
      def chain_first(klass_or_path, args)
        setup = Visitors::CommandSetup.new
        setup.command = klass_or_path
        setup.args_hash = args
        subject.chain_of_command.unshift(setup)
      end

      def up(levels = 1)
        return @nesting[-(levels+2)]
      end

      def root
        return @nesting[0]
      end
=end

      #:section: Miscellany

      #Not normally called from within an #action block, this provides the
      #default behavior for an undo (raise an exception)
      def undo(box)
        raise CommandException, "#{@name} cannot be undone"
      end

      #For big jobs - splitting them into subthreads and
      #such.  But they need to be debugged, and IIRC there's a deadlock
      #condition
      def action_thread(&block)
        collector = sub_collector
        return Thread.new do
          $stdout.set_thread_collector(collector)
          block.call
          $stdout.remove_thread_collector(collector)
        end
      end

      def fan_out(threads_at_a_time, array, &block)
        require 'thwait'

        array = array.to_a
        first_batch = (array[0...threads_at_a_time]||[]).map do |item|
          action_thread { block.call(item) }
        end

        rest = (array[threads_at_a_time..-1] || [])

        waiter = ThreadsWait.new(*first_batch)

        rest.each do |item|
          waiter.next_wait
          waiter.join_nowait(action_thread{block.call(item)})
        end

        waiter.join
      end
    end
  end
end
