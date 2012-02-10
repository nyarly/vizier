require 'vizier/arguments/base'
module Vizier
  #Liberally accepts any string as input
  class StringArgument < Argument
    register "string", String
    register "any"

    def state_complete(state, subject)
      return Orichalcum::CompletionHint.new(basis(state.subject))
    end

    def validate(term, subject)
      return true
    end
  end
end
