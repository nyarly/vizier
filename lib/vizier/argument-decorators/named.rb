require 'vizier/argument-decorators/base'
module Vizier
  #Indicated that the name of the argument has to appear on the command line
  #before it will be recognized.  Useful for optional or alternating arguments
  class Named < ArgumentDecoration
    register_as "named"

    def state_consume(state, subject)
      term = advance_term(state)
      if name == term
        state.unsatisfied_arguments.shift
        state.unsatisfied_arguments.unshift(decorated)
        return [state]
      else
        return []
      end
    end

    def state_complete(state, subject)
      prefix = completion_prefix(state) || ""
      if %r{^#{prefix.to_s}.*} =~ name.to_s
        return Orichalcum::CompletionResponse.create([name.to_s])
      else
        return Orichalcum::NullCompletion.singleton
      end
    end
  end
end
