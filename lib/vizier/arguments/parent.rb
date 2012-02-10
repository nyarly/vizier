require 'vizier/arguments/base'

module Vizier
  class ParentArgument < Argument
    register "parent"

    def state_complete(state, subject)

    end

    #XXX Find the parent?
    def validate(term, subject)
      return true
    end

    def state_consume(state, subject)
      if state.arg_hash.has_key?(@name)
        state.unsatisfied_arguments.shift
        return [state]
      else
        return []
      end
    end

  end
end
