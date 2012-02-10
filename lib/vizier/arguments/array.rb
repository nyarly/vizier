require 'vizier/arguments/base'
module Vizier
  #Created with an array of options to choose from
  class ArrayArgument < Argument
    register "array", Array
    register "choose"

    def validate(term, subject)
      return basis(subject).include?(term)
    end
  end
end
