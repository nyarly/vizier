require 'vizier/arguments'
require 'vizier/visitors'
require 'stencil/view'
require 'vizier/command-view'

module Vizier
  #A thin wrapper on Array to maintain undo/redo state.
  class UndoStack
    def initialize()
      @stack = []
      @now = 0
    end

    def add(cmd)
      @stack.slice!(0,@now)
      @now=0
      @stack.unshift(cmd)
    end

    def get_undo
      if @now > (@stack.length - 1) or @stack.length == 0
        raise CommandException, "No more commands to undo"
      end
      cmd = @stack[@now]
      @now+=1
      return cmd
    end

    def get_redo
      if @now <= 0
        raise CommandException, "Can't redo"
      end
      @now-=1
      return @stack[@now]
    end
  end

  #An overworked exception class.  It captures details about the command
  #being interrupted as it propagates up the stack.
  class ResumeFrom < ::Exception
    def initialize(pause_deck, msg = "")
      super(msg)
      @setup = Visitors::CommandSetup.new(nil)
      @pause_deck = pause_deck
    end

    attr_reader :setup, :pause_deck
  end

  class ResumeFromOnlyThis < ResumeFrom; end

  class Command
    def old_initialize(execution_context)
      raise CommandException, "#{@name}: unrecognized command" unless self.class.defined?
      @execution_context = execution_context

      @path = execution_context.command_path
      @nesting = execution_context.set_nesting
      subject = execution_context.subject
      context = execution_context.subject_context

      @argument_list = self.class.argument_list.dup
      @subject_requirements = self.class.subject_requirements.dup
      resolve_parent_arguments

      @subject_image = subject.get_image(subject_requirements || [], context)

      @arg_hash = {}
      @should_undo = true
      @validation_problem = CommandException.new("No arguments provided!")
      @last_completed_task = DontResume
      @resume_from = nil
      @main_collector = nil
    end

    def initialize(name)
      @name = name
      @argument_list= nil
      @tasks = []
      @task_list = nil
      @parent_arguments=[]
      @doc_text = nil
      @subject_requirements=[:chain_of_command]
      @defined = false
      @advice_block = proc {}
      @context = []
      @template_files = {}
    end

    attr_reader :name, :doc_text, :defined, :template_files

    def task_list
      @task_list ||= TaskList.new(@tasks.map{|task| task.to_list})
    end

    #GOAL: remove this method
    def argument_list
      task_list.argument_list
    end

    #GOAL: remove this method
    def subject_requirements
      task_list.subject_requirements
    end

    def tasks_changed
      @task_list = nil
    end

    def executable(execution_context)
      path = execution_context.command_path
      #nesting = execution_context.set_nesting
      subject = execution_context.subject
      context = execution_context.subject_context
      args_hash = execution_context.args_hash

      task_list.executable(path, args_hash, subject, context)
    end

    def task(klass)
      @tasks << klass
      klass.add_command(self)
      tasks_changed
    end

    if false #old stuff that I want to keep track of
      #Establishes a subclass of Command.  This is important because commands
      #are actually classes in CommandSet; their instances are specific
      #executions of the command, which allows for undo's, and history
      #management.  The block will get run in the context of the new class,
      #allowing you to quickly define the class completely.
      #
      #For examples, see Vizier::StandardCommands
      def setup(new_name=nil, &block)
        command_class = Class.new(self)
        new_name = new_name.to_s

        command_class.instance_variable_set("@name", new_name)

        command_class.instance_eval &block

        command_class.defined
        return command_class
      end

      def create_argument_methods
        names = argument_list.inject([]) do |list, arg|
          list + [*arg.names]
        end

        names.each do |name|
          define_method(name) do
            @arg_hash[name]
          end
          #private(name)

          define_method(name.to_s + "=") do |value|
            @arg_hash[name] = value
          end
          private(name.to_s + "=")
        end
      end
    end

    def parent_argument_list
      @parent_arguments
    end

    def select_command(name)
      nil
    end

    def complete_command(name)
      []
    end

    def complete_mode_command(name)
      []
    end

    def select_mode_command(name)
      nil
    end

    def defined
      @defined = true
      create_argument_methods
    end

    def defined?
      return @defined
    end

    def executeable?
      instance_methods.include?("execute")
    end

    def inspect
      arguments = argument_list.map{|arg| arg.name}

      return "#<Class:#{"%0#x" % self.object_id} - Command:#{name()}(#{arguments.join(", ")}) => #{@arg_hash.inspect}>"
    end

    def documentation(prefix=[])
      if @doc_text.nil?
        return short_docs(prefix)
      else
        return short_docs(prefix) +
          ["\n"] + @doc_text
      end
    end

    def short_docs(prefix=[])
      docs = prefix + [name]
      docs += arg_docs
      return docs.join(" ")
    end

    def arg_docs
      argument_list.map do |arg|
        if arg.required?
          "<#{arg.name}>"
        else
          "[#{arg.name}]"
        end
      end
    end

    extend DSL::CommandDefinition
    extend ArgumentHost
    extend CommandCommon
    include DSL::Action

    class DontResume; end

    attr_accessor :resume_from

    def resolve_settings
      @nesting.reverse.each do |set_nesting|
        if set_nesting.has_settings?
          #REMOVE ME?
        end
      end
    end

    def resolve_parent_arguments
      missing = []
      names = []
      self.class.parent_argument_list.uniq.each do |name|
        found = nil
        @nesting.reverse.each do |set_nesting|
          found = set_nesting.argument_list.find do |argument|
            [*argument.names].include? name
          end

          unless found.nil?
            @subject_requirements += found.subject_requirements
            @argument_list << found
            break
          end
        end
        if found.nil?
          missing << name
        else
          names += [*found.names]
        end
      end

      unless missing.empty?
        raise CommandError,
          "No parent has an argument named \"#{missing.join(", ")}\""
      end

      names.each do |name|
        (class << self; self; end).instance_eval do
          define_method(name) do
            @arg_hash[name]
          end
          private(name)

          define_method(name.to_s + "=") do |value|
            @arg_hash[name] = value
          end
          private(name.to_s + "=")
        end
    end
  end

  def required_arguments
    argument_list.find_all do |arg|
      arg.required?
    end
  end

  def all_arguments
    argument_list
  end

  def has_settings?
    arguments.any? do |argument|
      argument.has_feature Settable
    end
  end

  def validate_arguments
    raise @validation_problem if Exception === @validation_problem
    required_arguments.each do |argument|
      argument.check_present(@arg_hash.keys)
    end
  end

  attr_reader :arg_hash, :path, :nesting, :execution_context

  def inspect
    name = self.class.name
    return "#<Command:#{name}>:#{"%#x" % self.object_id} #{@arg_hash.inspect}"
  end

  def parent
    @nesting.last
  end

  def advise_formatter(formatter)
    formatter.receive_advice(&self.class.advice_block)
  end

  def view
    view = {}
    task_list.subject_requirements.each do |req|
      view[req.to_s] = @subject_image.__send__(req)
    end
    view
  end

  def undoable?
    return tasklist.undoable?
  end
end
end
