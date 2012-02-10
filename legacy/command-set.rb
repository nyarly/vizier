require 'strscan'
require 'thread'
require 'forwardable'
require 'vizier/errors'
require 'vizier/arguments'
require 'vizier/command'
require 'vizier/subject'
require 'vizier/results'
require 'vizier/dsl'
require 'vizier/visitors'


Vizier::wrap_stdout
#Vizier::wrap_stderr

#:startdoc:

#Vizier::CommandSet is a tight little library that lets you clearly and
#easily describe a set of commands for an interactive application.  The
#command set can then be handed to one of a number of interpreters that will
#facilitate interaction with the user.
#
#CommandSet has a number of pretty neat features:
#- A command line text interpreter, with tab completion etc. compliments of
#  readline.
#
#- A handy little DSL for describing commands and what they do.  There are
#  other CLI engines that map to ruby methods, but frankly, I'm not sure
#  that's the most useful mapping.  The CommandSet DSL lets you specify the
#  type of commands, control how they tab complete, mark some arguments as
#  optional, etc.
#
#- Modularized commands.  The StandardCommands class is a good example.
#  Basically, any time you have a command that might be generally
#  applicable, you can compose it into another set, and cherrypick specific
#  commands out.  For example:
#
#    CommandSet.define_commands do
#      command(:example) do |example|
#        ...stuff...
#      end
#
#      include(other_set)
#      include(cluttered_set, :useful)
#
#      sub_command(:sub) do |sub|
#        sub.include(yet_another_set)
#      end
#    end
#
#- Results processing.  Basically, any +puts+, +p+ or +print+ call in the
#  context of a command will (instead of outputing directly to +$stdout+)
#  instead fire events in Formatter objects.  The default behavior of which is
#  ... to output directly to +STDOUT+.  The catch here is that that behavior can
#  be changed, and the events can include the beginnings and ends of nesting
#  lists, so you have this whole tree of results from your command execution
#  that can be manipulated on it's way to the user.
#  As a for instance, you can spin off threads to do processing of parts of
#  a command, and be confidant that you'll be able to make sense of the
#  output for the user.
#
#- Extensible Command, Argument, and BaseInterpreter make power
#  functionality easy to add.  The modular design means that a CommandSet
#  written for use with the TextInterpreter, can also be used to process the
#  command line arguments to the program or passed to a batch interpreter.
#  WebApp (a separate gem) uses this feature so that a web application
#  automatically gets a command line version, for testing or administrator's
#  convenience.
#
#:include: doc/GUIDED_TOUR
module Vizier
  class RootCommand < Command
    class << self
      def setup(host, name)
        klass = super(name)
        klass.instance_variable_set("@host", host)
        return klass
      end
    end
  end

  #This class packs up a set of commands, for presentation to an
  #interpreter.  CommandSet objects are defined using methods from
  #DSL::CommandSetDefinition
  class CommandSet
    def initialize(name="")
      @name = name
      @command_list = { nil => RootCommand.setup(self, nil) {} }
      @mode_commands = {}
      @included_sets = []
      @documentation = ""
      @prompt = nil
      @arguments = []
      @most_recent_args = {}
      @subject_defaults = proc {|s|}
      @context = []
      @root_blocks = []
      @file_definitions = []
    end

    def initialize_copy(original)
      super
      base_list = original.instance_variable_get("@command_list")
      @command_list = {}
      @context = [] #original.context.dup
      base_list.each_pair do |name, cmd|
        @command_list[name] = cmd.dup
      end
    end

    attr_accessor :documentation, :most_recent_args
    attr_reader :root_blocks, :name

    class << self
      #The preferred way to use a CommandSet is to call CommandSet::define_commands with
      #a block, and then call #command, #include_commands
      #and #sub_command on it.
      def define_commands(&block)
	set = self.new
	set.define_commands(&block)
	return set
      end

      #In driver code, it's often quickest to yank in commands from a file.
      #To do that, create a code file with a module in it.  The module needs
      #a method of the form
      #
      #  def self.define_commands()
      #
      #define_commands should return a CommandSet.  Then, pass the require
      #path and module name to require_commands, and it'll take care of
      #creating the command set.  You can even call
      #DSL::CommandSetDefinition#define_commands on the set that's returned
      #in order to add one-off commands or fold in other command sets.
      def require_commands(mod, file=nil, cmd_path=[])
        set = self.new
        set.require_commands(mod, file, cmd_path)
        return set
      end
    end

    include DSL::CommandSetDefinition
    include Common
    extend Forwardable

    def_delegators("@command_list[nil]", *ArgumentHost.instance_methods)
    def_delegators("@command_list[nil]", *DSL::CommandDefinition.instance_methods)
    def_delegators("@command_list[nil]", :new, :template_string, :template)

    #:section: Workhorse methods - not usually used by client code
    #
    def select_command(name)
      @command_list[name]
    end

    def select_mode_command(name)
      @mode_commands[name]
    end

    def complete_command(prefix)
      return @command_list.keys.grep(/^#{prefix}/)
    end

    def complete_mode_command(prefix)
      return @mode_commands.keys.grep(/^#{prefix}/)
    end

    def command_list
      return @command_list.merge(@mode_commands)
    end

    def mode_commands
      return @mode_commands.dup
    end

    def get_root
      command = @command_list[nil]
    end

    def apply_root_blocks(blocks)
      @root_blocks += blocks
      blocks.each do |block|
        @command_list[nil].instance_eval(&block)
      end
    end

    def get_subject
      subject = Subject.new
      add_requirements(subject)
      add_defaults(subject)
      return subject
    end

    def add_defaults(subject)
      included_subject = @included_sets.inject(Subject.new) do |merger, (subset, options)|
        merger.merge(options[:context], subset.get_subject)
      end
      subject.absorb(included_subject)
      @subject_defaults.call(subject)
    end

    def template_files
      @command_list[nil].template_files
    end

#    def define_files(path, valise)
#      @command_list[nil].template_files.each_pair do |root_path, contents|
#        valise.add_file([root_path, "templates"] + path + %w{_root_}, valise.align(contents))
#      end
#
    #This is the part of this method maybe worth saving
#      @file_definitions.each do |prok|
#        valise.define(&prok)
#      end
#    end

    def files(&block)
      @file_definitions << (proc &block)
    end

    def prompt
      if @prompt.nil?
        if @name.empty?
          return [/$/, ""]
        else
          return [/$/, "#@name : "]
        end
      else
        return @prompt
      end
    end

    def set_prompt(match, replace)
      @prompt = [match, replace]
    end

    def documentation(prefix=[])
      docs = ""
      docs = @command_list.to_a.reject do |el|
	el[0].nil?
      end

      parent = prefix + [@name]
      docs = docs.sort_by{|el| el[0]}.inject([]) do |doclist,cmd|
        doc = cmd[1].short_docs(parent)
        #raise "Malformed documentation at #{parent}, #{cmd.inspect}:
        ##{doc.inspect}" unless Array === doc
	doclist += [doc]
      end.join("\n")

      return docs
    end

    def arg_docs
      ""
    end

    alias short_docs documentation
    alias doc_text documentation

    def build_command(home, name_or_class, name_or_nil, block)
      if Class === name_or_class && Command > name_or_class
        if block.nil?
          command = name_or_class.dup
          name = command.name
        else
          name = name_or_nil.to_s
          command = name_or_class.setup(self, name, &block)
        end
      else
        if String === name_or_class or Symbol === name_or_class
          name = name_or_class.to_s
        else
          raise RuntimeError, "#{name_or_class} is neither a Command class nor a name!"
        end
        command = Command.setup(name, &block)
      end

      home[name] = command
    end
  end
end
