

=begin
  class MyTemplateBuilder < Vizier::TemplateBuilder
    command_set do
      require 'myapp/commands'
      MyApp::Commands::setup_commands
    end

    template_path [""] + %w{etc myapp templates}, %{~ .myapp templates}
  end

  MyTemplateBuilder.go
=end

require 'valise'
require 'vizier/visitors/base'

module Vizier::Visitors
  class TemplateBuilder < Collector
    class << self
      def command_set
        @command_set = yield
      end

      def get_command_set
        @command_set
      end

      def template_path(*args)
        @template_path = args
      end

      def get_template_path
        @template_path
      end

      def go
        churn([self.new(Valise.new(get_template_path, get_command_set))])
      end
    end

    def initialize(valise, node)
      super(node)
      @valise = valise
    end

    attr_reader :valise

    def open
      path = @command_path.dup
      template_string = node.template_string
      #path = node.template_path
      path = []

      path[-1] = path[-1] + ".sten"

      if template_string.nil?
        path[-1] = path[-1] + ".example"
        @valise.add_file(path, "")
      else
        @valise.add_file(path, template_string)
      end

      super
    end
  end
end
