require 'vizier/visitors/input-parser'
require 'orichalcum/completion-response'

module Vizier
  module Visitors
    class FindCompleters < InputParser
      def go(root_node, input)
        add_state(CommandArgumentsState.new(root_node, input))
        begin
          solution = resolve
          #  return CompletionList.new([solution.parsed_tokens.last])
        rescue CommandException => ce
        end

        completions
      end

      def filter_completing(states)
        completing, uncompleting = states.partition{|state| state_completing?(state)}
        @completers += completing.map{|state| state.dup}
        return states #uncompleting
      end

      def filter_continuing(states)
        super(filter_completing(states))
      end

      def solution
        @completers
      end

      def initialize(subject)
        super
        #@completions = Orichalcum::NullCompletion.singleton
        @completers = []
      end

      attr_accessor :completers

      def invalid?(state)
        return (super || (Class === state.node and state.node.name.nil?))
      end

      def state_completing?(state)
        return true if state.parsed_tokens.empty? and state.remaining.empty?
        return (state.check(/\A(\s+(['"])(?:(?!\2).)*(?:\2)?)/, /\A(\s+\S*)/) && state.post_match.empty?)
      end
    end

    class ResolveCompletion < CommandAndArgument
      def open(state)
        if state.has_arguments?
          state.first_argument.completing_states(state, @subject)
        else
          []
        end
      end

      def no_solution
        Orichalcum::NullCompletion.singleton
      end

      def solution
        return @closed_states.map do |state|
          get_completions(state)
        end.inject do |list, more|
          list.merge(more)
        end
      end

    end

  end
end
