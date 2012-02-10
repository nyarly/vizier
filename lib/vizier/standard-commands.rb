#This is a collection of useful commands that are often useful to add to
#DSL::CommandSetDefinition#include_commands
#
#(Ahem: this docco is wrong and needs to be fixed)
#For instance
#
# set = CommandSet::define_commands do
#   include_commands Vizier::StandardCommands::Quit
#   include_commands Vizier::StandardCommands::Undo
#   include_commands Vizier::StandardCommands::Help
# end
#
#Or you could use Vizier::DSL::require_commands, like so
#
# set = CommandSet::define_commands do
#   require_commands "StdCmd::Quit", "vizier/standard_commands",
#   require_commands "StdCmd::Undo"
#   require_commands "StdCmd::Help"
# end
#
#Some notes:
#
#0. Resume is usually handy for use in +chain+ calls, not as something to
#   present for the user to access directly.  It resumes paused commands.
#0. Mode is useful in subcommands.  Including it lets the user use the
#   subcommand by itself to switch into a mode where that subcommand is
#   the root command set.  Then "exit" lets them leave and return to the
#   regular set.  Consider IOS's config mode, for instance.
#0. Set is useful for allowing the user to update program settings on the
#   fly.  It assumes a set of nested hashes that represent the settings.
#   It functions as you'd (hopefully) expect.  +set+ +optionname+ returns
#   the current value, +set+ +optionname+ +value+ sets the value of
#   +optionname+

require 'vizier/standard-tasks'
require 'vizier/command-description'

module Vizier
  module StandardCommands
    class << self
      def undo
        @undo_commands = Vizier::define_commands("undo") do
          command :undo do
            task Task::Undo
          end

          command :redo do
            task Task::Redo
          end
        end
      end

      def set
        @set_commands = Vizier::define_commands("set") do
          command :add do
            task Task::Set::Add
          end

          command :clear do
            task Task::Set::Clear
          end

          command :remove do
            task Task::Set::Remove
          end

          command :reset do
            task Task::Set::Reset
          end

          command :show do
            task Task::Set::Show
          end

          command :set do
            task Task::Set::Set
          end
        end
      end

      def basics
        set_commands = self.set
        @basic_commands = Vizier::define_commands("basic") do
          command :quit do
            task Task::Quit
            #template_for :text, ""
          end

          command :help do
#            document <<-EOH
#          Returns a hopefully helpful description of the command indicated
#            EOH

            task Task::Help

#            template_for(:text, <<-EOT)
#          <<<
#          [;
#          each /:commands command ;][;
#          = @command:name;] [;
#          each @command:arguments arg;][;
#            = @arg ;][;if @arg+1;] [;end;][;
#          end;][;
#          if @/:mode == "single";]
#
#          [;
#            indent @/:indent;][;
#              wrap @/:width - @/:indent;][;
#                = @command:documentation;][;
#              end;][;
#            end;][;
#          end;]
#          [;end;]
#            EOT
          end
          merge(set_commands)
        end
      end
    end
  end

  class Registry
    register{ StandardCommands::undo }
    register{ StandardCommands::set }
    register{ StandardCommands::basics }
  end
end
