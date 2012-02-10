require 'vizier/registry'
require 'vizier/dsl/argument'
require 'vizier/task/base'
module Vizier
  class << self
    def describe_commands(name=nil, &block)
      calling_file = CommandDescription.get_caller_file
      name ||= File::basename(calling_file, ".rb")
      CommandDescription.command(name, calling_file, &block)
    end

    def extend_command(command, path, &block)
      calling_file = CommandDescription.get_caller_file
      CommandDescription.add_to(command, path, calling_file, &block)
    end

    #Backwards compatibility - describe_commands is preferred
    alias define_commands describe_commands
  end

  module SingleTask
    #Worth guarding against mix?
    def task_class
      @task_class ||=
        begin
          puts "Deprecated single task class syntax"
          klass = Class.new(Task::Base)
          @described.task(klass)
          klass
        end
    end

    def action(&block)
      task_class.instance_eval do
        define_method(:action, &block)
      end
    end

    def undo(&block)
      task_class.instance_eval do
        define_method(:undo, &block)
      end
    end

    include DSL::Argument

    def embed_argument(argument)
      task_class.embed_argument(argument)
    end

    def doesnt_undo
      task_class.instance_eval do
        define_method(:undo){}
      end
    end

    def subject_methods(*names)
      task_class.subject_methods(*names)
    end
    alias subject_method subject_methods
  end

  class CommandDescription
    class PathHints
      def initialize()
        @hints = []
      end
      attr_reader :hints

      def add(stem, root)
        @hints << [stem, root]
      end

      def prepend(stem, root)
        raise "nil stem" if stem.nil?

        @hints.unshift([stem, root])
      end

      def merge(other)
        @hints = (@hints + other.hints).uniq
      end

      def relocate(to_stem, with_trim)
        make = self.class.new
        @hints.each do |stem, root|
          stem_trim = with_trim[0...stem.length]
          next if stem.length >= with_trim.length and stem_trim != stem
          stem = stem[stem_trim.length..-1]
          root_trim = with_trim[stem.length..-1]
          make.add(to_stem + stem, root_trim + root)
        end
        make
      end
    end

    def self.get_caller_file
      caller(0)[2].sub(/:.*/,'')
    end

    def self.command(name, calling_file=nil, &block)
      calling_file ||= get_caller_file
      return self.new(Command.new(name), calling_file, &block)
    end

    def self.add_to(command, path, calling_file=nil, &block)
      finder = Visitors::Command.new(nil)
      finder.add_state(VisitStates::CommandPath.new(command, path))
      subcommand = finder.resolve.node
      return CommandDescription.new(subcommand, calling_file, &block)
    end

    include SingleTask

    def initialize(command, path = nil, stem = nil, &block)
      @call_path = path || self.class.get_caller_file
      @template_root = default_template_root
      @path_hints = PathHints.new
      @stem = stem || []
      @described = command
      instance_eval &block unless block.nil?
      @path_hints.prepend(@stem, @template_root)
    end

    attr_reader :path_hints, :described

    def file_set
      set = Valise::Set.new
      @path_hints.each do |stem, root|
        search_root = Valise::SearchRoot.new(root)
        if !stem.empty?
          search_root = Valise::StemDecorator.new(stem, search_root)
        end
        set.add_search_root(search_root)
      end
    end

    def add_to(path, &block)
      finder = Visitors::Command.new(nil)
      finder.add_state(VisitStates::CommandPath.new(described, path))
      subcommand = finder.resolve.node
      return CommandDescription.new(subcommand, &block)
    end

    def command(name, &block)
      sub_desc = CommandDescription.new(Command.new(name), @call_path, @stem + [name], &block)
      compose(sub_desc.described, nil)
    end

    def templates(path)
      @template_root = path
    end

    alias templates= templates

    def default_template_root
      File::expand_path(@call_path, "../../templates").split(File::Separator)
    end

    def compose(command, path_hints)
      @described.add_child(command)
      @path_hints.merge(path_hints) unless path_hints.nil?
    end

    def merge(description, *filters)
      if filters.empty?
        description.described.child_commands.each do |child|
          compose(child, description.path_hints.relocate(@stem + [@described.name], [child.name]))
        end
      else
        filters.each do |filter|
          child = description.described.find_command(filter)
          compose(child, description.path_hints.relocate(@stem + [@described.name], filter))
        end
      end
    end

    def from_file(path, *filters)
      added = []
      sub_desc = CommandDescription.new(:holder, @call_path, @stem + [:holder]) do
        Registry.thread_local.notify_registrations(path) do |name, description|
          compose(description.described, description.path_hints)
          added << name
        end
      end
      filters = added if filters.empty
      merge(sub_desc, filters)
    end

    def task(klass)
      @described.task(klass)
    end

    def subject_defaults(hash)
      @described.subject_defaults = hash
    end

    def documentation(string)
      @described.doc_text = string
    end
  end
end
