require 'vizier/arguments/base'
module Vizier
  #Consumes the rest of the line as a space separated string.
  #Useful for commands with sentences as their arguments.
  class RestOfLineArgument < StringArgument
    register "rest"

    def consume(subject, arguments)
      term = arguments.join(" ")
      arguments.clear
      return {@name => term}
    end
  end
end
