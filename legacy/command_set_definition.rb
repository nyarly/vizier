module Vizier
  module DSL

    #These are the commands available within the CommandSet::define_commands
    #block.
    module CommandSetDefinition
      #Allows other command sets to be composited into this one.  And
      #optional list of command names will cherry-pick the commands of the
      #other set, otherwise they're all folded in, with preference given to
      #the new commands.
      def include_commands(set, *commands)
        new_commands = set.command_list
        new_mode_commands = set.mode_commands
        options = Hash === commands.first ? commands.shift : {}

        commands.map!{|c| c.to_s}
        unless commands.empty?
          new_commands.delete_if do |name,command|
            not commands.include? name
          end
          new_mode_commands.delete_if do |name, command|
            not commands.include? name
          end
        end

        unless new_commands.empty? and new_mode_commands.empty?
          @included_sets << [set, options]
        end

        if new_commands.has_key?(nil)
          apply_root_blocks(set.root_blocks)
        end

        new_commands.each_pair do|name, command|
          next if name.nil?
          if(CommandSet === @command_list[name])
            next unless CommandSet === command
            @command_list[name].include_commands(command)
          else
            @command_list[name] = command
          end
          unless(options[:context].nil?)
            @command_list[name] = Visitors::ContextBoundary.new(@command_list[name],
                                                                options[:context])
          end
        end

        new_mode_commands.each_pair do |name, command|
          @mode_commands[name] = command
        end
      end

      #If you've got a file dedicated to a set of commands, (and you really
      #should) you can use require_commands to require it, call
      #+define_commands+ on a specific Module, pick out a specific
      #subcommand (by passing a path), and then including specific commands
      #from it.
      def require_commands(module_name, file = nil, path = [], *commands)
        require file rescue nil

        if Module === module_name
          mod = module_name
        else
          module_path = module_name.to_s.split("::")
          mod = Object
          module_path.each do |part|
            mod = mod.const_get(part)
          end
        end

        set = mod.define_commands
        unless CommandSet === set
          raise RuntimeError,"#{set.inspect} isn't a CommandSet"
        end

        set = set.find_command(path)

        if CommandSet === set
          include_commands(set, *commands)
        elsif Class === set and Command > set
          command(set)
        else
          raise RuntimeError,"#{set.inspect} isn't a CommandSet or a Command"
        end
      end

      #Defines a command.  Either:
      #- pass a name and a block, which will create the command on
      #  the fly - within the block, use methods from
      #  Vizier::DSL::CommandDefinition.
      #- pass a Command subclass - which will be added to the set based on it's name.
      #- pass a Command subclass, a name, and a block.  The new command will
      #  be a subclass of the class you passed in, which is great for a
      #  series of related commands.
      def command(name_or_command_class, name_or_nil=nil, &block)
        if name_or_command_class.nil?
          command = @command_list[nil]
          command.instance_eval(&block)
          return
        else
          build_command(@command_list, name_or_command_class,
                        name_or_nil, block)
        end
      end

      def command_alias(name, command)
        if Array === command
          command = find_command(command)
        end

        @command_list[name] = command
      end

      def mode_command(name_or_class, name_or_nil=nil, &block)
        build_command(@mode_commands, name_or_class, name_or_nil, block)
      end

      #Defines a nested CommandSet.  Commands within the nested set will be
      #referenced by preceding them with the name of the set.
      #DSL::CommandSetDefinition will be available within the block to be
      #used on the subcommand
      def sub_command(name, &block)
        @subject_template = nil
        name = name.to_s

        if (@command_list.has_key? name) && (CommandSet === @command_list[name])
          command = @command_list[name]
        else
          command = CommandSet.new(name)
          @command_list[name] = command
        end

        command.define_commands(&block)
        #paths_update(command, name)
      end

      #When the behavior of a includeable command set should alter the root
      #command of another command set, use root_command to wrap the command
      #definition methods - loose command definition stuff will apply to the
      #command as is, but won't be updated into including sets.
      #
      #As a for instance, take a look at StdCmds::Mode
      def root_command(&block)
        apply_root_blocks([block])
      end

      #This is the method that makes DSL::CommandSetDefinition available.
      #It's just a wrapper on instance_eval, honestly.
      def define_commands(&block)
        instance_eval(&block)
      end

      def subject_defaults(&block)
        @subject_defaults = proc &block
      end
    end
  end
end
