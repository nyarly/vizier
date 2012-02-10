require 'vizier/arguments/base'
module Vizier
  #Input has to be a number, in the range passed to create the argument
  class NumberArgument < Argument
    register "number", Range
    register "range"

    def complete(terms, prefix, subject)
      return Orichalcum::NullCompletion.singleton unless validate(prefix, subject)
      return Orichalcum::CompletionResponse.create([prefix])
    end

    def validate(term, subject)
      value = parse(subject, term)
      range = basis(subject)
      return false if not range.nil? and not range.include?(value)
      return true if %r{^0(\D.*)?} =~ term
      return value != 0
    end

    def parse(subject, term)
      return term.to_i
    end
  end
end
