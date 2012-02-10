require 'vizier/arguments'
require 'vizier/visitors'
require 'stencil/view'
require 'vizier/command-view'
require 'vizier/undo-stack'
require 'vizier/tasklist'

module Vizier

  class Command
    def initialize(name)
      @name = name
      @tasks = []
      @task_list = nil
      @parent_arguments=[]
      @doc_text = nil
      @defined = false
      @advice_block = proc {}
      @context = []
      @template_files = {}
      @child_commands = []
      @child_names = nil
      @subject_defaults = {}
    end

    attr_reader :name, :doc_text, :defined, :template_files
    attr_reader :arg_hash, :path, :nesting, :execution_context, :child_commands

    def task_list
      @task_list ||= TaskList.new(*(@tasks.map{|task| task.to_list}))
    end

    def inspect
      (["(Command: #{@name}:#{task_list.argument_list.inspect})"] +
      @child_commands.map do |child|
        begin
          child.inspect.split("\n").map do |line|
            "  " + line
          end.join("\n")
        end
      end).join("\n") +
        (@child_commands.empty? ? " x )" : ")")
    rescue Object => ex
      p [ex, ex.backtrace[0..2]]
      super
    end

    #GOAL: remove this method
    def argument_list
      task_list.argument_list
    end

    #GOAL: remove this method
    def subject_requirements
      task_list.subject_requirements
    end

    def subject_defaults=(hash)
      @subject_defaults = hash
    end

    def tasks_changed
      @task_list = nil
    end

    def undoable?
      return tasklist.undoable?
    end

    def executable(execution_context)
      path = execution_context.command_path
      #nesting = execution_context.set_nesting
      subject = execution_context.subject
      context = execution_context.subject_context
      args_hash = execution_context.arg_hash

      task_list.executable(path, args_hash, subject, context)
    end

    def task(klass)
      @tasks << klass
      klass.add_command(self)
      tasks_changed
    end

    def add_child(command)
      @child_names = nil
      @child_commands << command
    end

    #XXX Visitor?
    def find_child(*path)
      idx = path.pop
      child = select_command(idx)

      if child.nil?
        return nil
      elsif path.empty?
        return child
      else
        return child.find_child(*path)
      end
    end

    def parent_argument_list
      @parent_arguments
    end

    def child_names
      @child_names ||= @child_commands.map{|cmd| cmd.name}
    end

    def select_command(name)
      name = name.to_sym
      @child_commands.find{|cmd| cmd.name == name}
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

    def executeable?
      !@tasks.empty? and task_list.executable?
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

    #XXX Arg docs in Argument, surely?
    def arg_docs
      argument_list.map do |arg|
        if arg.required?
          "<#{arg.name}>"
        else
          "[#{arg.name}]"
        end
      end
    end

    class DontResume; end

    attr_accessor :resume_from

    def add_requirements(subject)
      subject.required_fields(task_list.subject_requirements)
    end

    def add_defaults(subject)
      task_list.subject_defaults.merge(@subject_defaults) do |key, value|
        subject[key] = value
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
  end
end
