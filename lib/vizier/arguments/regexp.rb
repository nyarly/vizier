require 'vizier/arguments/base'
module Vizier
  #Input must match the regular expression passed to create this Argument
  class RegexpArgument < Argument
    register "regexp", Regexp
    register "regex"

    def complete(terms, prefix, subject)
      return [prefix]
    end

    def validate(term, subject)
      return basis(subject) =~ term
    end
  end
end
