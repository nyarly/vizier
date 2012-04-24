require 'vizier/arguments'
require 'vizier/visit-states'
require 'orichalcum/completion-response'
require 'forwardable'
require 'vizier/debug'

module Vizier
  module Visitors
    class Command
      include Debug

      def initialize(subject)
        @subject = subject
        @states = []
        @closed_states = []
        @complete_states = []
        @invalid_states = []
      end
      attr_reader :states, :complete_states, :invalid_states, :subject

      def complete?(state)
        return state.terms_complete?
      end

      def invalid?(state)
        state.node.nil?
      end

      #"open" in this context means to parse the next unit of input, and return
      #1 or more states updated to reflect that parse - including adding the
      #parsed input to a parsed list, altering the unparsed input and adjusting
      #the current node in the command tree and the arguments list.
      #
      #The current argument or else the command gets to do the tokenize
      #
      def open(state)
        term = next_term(state)
        debug :open => [term, state]

        if term.nil?
          return []
        else
          return [command_open(term, state)]
        end
      end

      def next_term(state)
        state.advance_term
      end

      def command_open(term, state)
        state.command_path << term
        state.node = state.node.select_command(term)
        state
      end

      def no_solution
        best_closed = @closed_states.max_by{|state| state.priority}
        raise CommandException, "Having understood \"#{best_closed.parsed_tokens.join(" ")}\": couldn't understand: #{best_closed.remaining}\n #{best_closed.inspect}"
      end

      def setup
      end

      def filter_valid(states)
        invalid, valid = states.partition{|state| invalid?(state)}
        debug :invalid => invalid
        @invalid_states += invalid
        return valid
      end

      def filter_continuing(states)
        complete, incomplete = filter_valid(states).partition{|state| complete?(state)}
        debug :complete => complete
        @complete_states += complete
        debug :incomplete => incomplete
        return incomplete
      end

      #Assign priority here?
      def add_states(*states)
        debug :filtering => states
        @states += filter_continuing(states)
        @states.sort_by!{|state| state.priority}
      end
      alias add_state add_states

      def one_cycle
        state = @states.pop
        debug :one_cycle => [state, "and #{@states.length} more"]

        @closed_states << state

        p self.class
        add_states(*(open(state)))
      end

      def resolve
        debug :resolving => self.class

        setup
        while unresolved? do
          one_cycle
        end

        result = (solution or no_solution)

        debug :solution => result

        return result
      end

      def solution
        return complete_states.first
      end

      def unresolved?
        complete_states.empty? and not states.empty?
      end
    end

    class Collector < Command
      def complete?(state)
        false
      end

      def open(state)
        names = state.node.child_names
        return names.map do |name|
          command_open(name, state.dup)
        end
      end

      def solution
        return @closed_states
      end
    end

    class CommandAndArgument < Command
      def open(state)
        if state.has_arguments?
          return state.first_argument.state_consume(state, @subject)
        else
          return super
        end
      end

      def complete?(state)
        return (not state.has_arguments? and super)
      end

      #XXX This is the first place to look when re-implementing mode_commands
      #return
      #Orichalcum::CompletionResponse.create(@node.complete_mode_command("")
      #| @node.complete_command(""))
      #if state.parsed_tokens.empty?
      #  comp |= @node.complete_mode_command(term)
      #end
      def get_completions(state)
        return Orichalcum::NullCompletion.singleton if state.node.nil?
        if state.has_arguments?
          return state.unsatisfied_arguments.first.state_complete(state, subject)
        else
          match_term = state.peek_term || ""
          comp = state.node.child_names.grep(%r{^#{match_term}})
          response = Orichalcum::CompletionResponse.create(comp)
          response.prefix = match_term
          return response
        end
      end
    end

  end
end
