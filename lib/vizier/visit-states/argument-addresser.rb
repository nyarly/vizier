require 'vizier/visitors/base'

raise "This file currently not suitable for use"
#Should either become a subclass of VisitState or get absorbed where it's used
module Vizier
  module Visitors
    class ArgumentAddresser < Command
      #TODO: this looks like parent's command_open...

      def initialize(node, modules)
        super(node)
        @modules = modules
      end

      def completions(term)
        return [] if invalid?

        completions = @node.argument_list.find_all{|argument|
          @modules.all?{|mod| argument.has_feature(mod)}
        }.map{|argument| argument.name}
        completions += @node.command_list.keys
        completions += @node.mode_commands.keys
        return completions.grep(/^#{term}.*/)
      end

      def get_argument(name)
        @node.argument_list.find do |argument|
          argument.name == name and @modules.all?{|mod| argument.has_feature(mod)}
        end
      end
    end
  end
end
