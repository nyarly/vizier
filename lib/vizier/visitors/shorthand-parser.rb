require 'vizier/visitors/input-parser'

module Vizier
  module Visitors
    class ShortHandParser < InputParser
      def next_term(state)
        term = state.advance_term
        completions = get_completions(state)
        term = completions.unique_complete(term)
        state.parsed_tokens[-1] = term
        return term
      end
    end
  end
end
