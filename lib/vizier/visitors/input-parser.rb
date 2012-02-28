require 'vizier/visitors/base'

module Vizier
  module Visitors
    #XXX: really needed?
    class ArgHash < Hash
      def merge!(hash)
        hash = hash.dup
        shared = hash.keys & self.keys
        shared.each do |key|
          me = self[key]
          me = [me] unless Array === me
          you = hash.delete(key)
          you = [you] unless Array === you
          self[key] = me + you
        end
        return super(hash)
      end

      def merge(hash)
        return self.dup.merge!(hash)
      end
    end

    class InputParser < CommandAndArgument
      def setup
        #@states |= @states.map{|state| mode_command_open(state)}
        @states.each do |state|
          state.unsatisfied_arguments = state.node.argument_list.find_all do |arg|
            arg.has_feature(Settable)
          end unless state.node.nil?
        end
      end
      #
#      def mode_command_open(state)
#        new_state = state.dup
#        term = new_state.advance_term
#        new_state.command_path << term
#        new_state.node = new_state.node.select_mode_command(term)
#        return new_state
#        #return [new_state] + command_open
#      end

      def command_open(term, state)
        state = super
        state.set_nesting << state.node
        unless state.node.nil?
          state.unsatisfied_arguments = state.node.argument_list.dup
        return state
      end
    end
  end
end
