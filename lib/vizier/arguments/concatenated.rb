require 'vizier/arguments/complex'
module Vizier
  #A concatenated argument allows for several arguments to be treated as a
  #whole: useful for applying decorators like "optional" to a set of arguments
  #that should all be specified or none.
  class ConcatenatedArgument < ComplexArgument
    def state_consume(state, subject)
      state.unsatisfied_arguments.shift
      state.unsatisfied_arguments.insert(0, *@argument_list)
      return [state]
    end

    def completing_states(state, subject)
      state_consume(state, subject)
    end

    def state_complete(state, subject)
      return NullCompletion.singleton
    end
  end
end
