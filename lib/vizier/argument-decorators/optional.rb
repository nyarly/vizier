require 'vizier/argument-decorators/base'
require 'orichalcum/completion-response'

module Vizier
  #Most common decorator.  Tags a argument as omitable.  Otherwise, the
  #interpreter will return an error to the user if they leave out an
  #argument.  Optional arguments that aren't provided are set to nil.
  class Optional < ArgumentDecoration
    register_as "optional"

    def state_consume(state, subject)
      state.unsatisfied_arguments.shift
      state_with = state.dup
      state_with.unsatisfied_arguments.unshift(decorated)
      return [state_with, state]
    end

    def state_complete(state, subject)
      return Orichalcum::NullCompletion.singleton
    end

    def completing_states(state, subject)
      state_consume(state, subject)
    end

    def required?
      false
    end
  end
end
