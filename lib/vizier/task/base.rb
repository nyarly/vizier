module Vizier
  module Task
    class Base
     module ClassMethods
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
            @subject_image[name]
          end
          define_method("#{name}=") do |val|
            @subject_image[name] = val
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

      def initialize(command_path, args_hash, subject_image)
        @nesting = command_path
        @args_hash = args_hash
        @subject_image = subject_image
      end

      def name
        (self.class.name || "<unnamed>").sub(/\A.*::/,"").downcase
      end

      def subject_view
        view = {}
        self.class.subject_requirements.each do |req|
          view[req.to_s] = @subject_image[req]
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
