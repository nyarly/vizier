module Vizier
=begin rdoc
This module collects the domain specific languages for Vizier.
This is the first and best place to start if you want to try to understand
how to make use of Vizier.

The sub-modules here are (in rough "nesting" order):

CommandSetDefinition:: the commands with a Vizier::define_commands block
CommandDefinition:: the commands with a command setup block that describe how a command functions
Argument:: the chained descriptors that describe how arguments are interpreted by command definitions
Action:: utility functions within the command action block

So, something like:

 Vizier::define_commands do
 #Use CommandSetDefinition here
   command :do do
     #Use CommandDefinition and Argument here

     optional.argument :what_to_do, "What, John?"

     action do
       #Use Action here
     end
   end
 end
=end
  module DSL
    require 'vizier/dsl/argument'

    module CommandView
      def subject
        data.subject
      end
    end

    require 'vizier/dsl/command_definition.rb'
    require 'vizier/dsl/formatting.rb'
    require 'vizier/dsl/action.rb'
  end
end
