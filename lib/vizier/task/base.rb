module Vizier
  module Task
    class Base
      class Registry
        def initialize
          @register = {}
        end

        def []=(name, task)
          @register[name.to_s] = task
        end

        def match_names(prefix)
          re = %r{\A#{prefix}::.*}
          @register.keys.find_all{|name| re =~ name}
        end

        def search(prefix)
          @register.values_at(*match_names(prefix))
        end
      end

      class SubjectAdapter
        def initialize
          @mappings = {}
        end

        def add_mapping(from, to)
          @mappings[from.to_sym] = to.to_sym
        end

        def deref(from)
          @mappings[from.to_sym] || from
        end
      end

      module ClassMethods
        def task_registry
          @@task_registry ||= Registry.new
        end

        def subject_adapter
          @subject_adapter ||= SubjectAdapter.new
        end

        def inherited(sub)
          return if sub.name.nil?
          Vizier::Task::Base.task_registry[sub.name] = sub
        end

        def adapted(&block)
          Class.new(self, &block)
        end
        alias subclass adapted
        alias except adapted

        #TODO adjust subject requirements as well
        def fixed_argument(name, value)
          arg_idx = argument_list.index{|arg| arg.name == name}
          return if arg_idx.nil?
          arg = argument_list.delete_at(arg_idx)
          arg.names.each do |name|
            define_method(name) do
              value
            end
          end
        end

        #Subclassing and argument lists?
        def rename_argument(from, to)
          arg = argument_list.find{|arg| arg.name == from}
          return if arg.nil?
          arg.name = to
          define_method(from) do
            @args_hash[to]
          end
        end

        def before(other)
          other.pre_deps << self
          other.notify_commands
        end

        def after(other)
          other.post_deps << self
          other.notify_commands
        end

        def undoable
          self.instance_method(:undo)
          return true
        rescue NameError
          return false
        end

        def pre_deps
          @pre_deps ||= []
        end

        def post_deps
          @post_deps ||= []
        end

        def to_list
          pre_deps.map{|dep| dep.to_list} +
            [self, *post_deps.map{|dep| dep.to_list}]
        end

        def host_commands
          @host_commands ||= []
        end

        def add_command(command)
          host_commands << command
        end

        def notify_commands
          @host_commands.tasks_changed
        end

        def subject_requirements
          @subject_requirements ||= []
        end

        def subject_requirements=(list)
          @subject_requestments = list
        end

        def subject_defaults
          @subject_defaults ||= {}
        end

        def subject_methods(*names)
          names.each do |name|
            subject_method(name)
          end
        end

        NoDefault = Object.new.freeze

        #XXX: consider fallback: argument to subject to setting...
        def subject_method(name, default = NoDefault)
          subject_requirements << name
          subject_defaults[name] = default unless default.equal? NoDefault

          define_method(name) do
            @subject[subject_deref(name)]
          end
          define_method("#{name}=") do |val|
            @subject[subject_deref(name)] = val
          end
        end

        def embed_argument(arg)
          super
          arg.names.each do |name|
            define_method(name) do
              @args_hash[name]
            end
          end
        end

        def argument_list
          @argument_list ||= superclass.argument_list
        rescue NoMethodError
          @argument_list ||= []
        end

        def argument_list=(list)
          @argument_list = list
        end
      end

      extend DSL::Argument
      extend ArgumentHost
      extend ClassMethods

      include DSL::Action

      def subject_deref(name)
        name = self.class.subject_adapter.deref(name)
        name = super(name)
      rescue NoMethodError
        name
      end

      def initialize(command_path, args_hash, subject)
        @nesting = command_path
        @args_hash = args_hash
        @subject= subject
      end

      def name
        (self.class.name || "<unnamed>").sub(/\A.*::/,"").downcase
      end

      def subject_view
        view = {}
        self.class.subject_requirements.each do |req|
          view[req.to_s] = @subject[req]
        end
        view
      end

      def execute(output)
        action(output)
      end

      def reverse(output)
        undo(output)
      end
    end

  end
end
