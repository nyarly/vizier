require 'vizier/visitors/base'

module Vizier
  module Visitors

    #Really, "search_root" should be "searchroot"
    class FilesetEnricher < Collector
      def initialize(search_root, def_templs)
        super
        @search_root = search_root
        @default_templates = def_templs
      end

      attr_reader :search_root, :default_templates

      def define_files(state)
        (default_templates.merge(state.node.template_files)).each_pair do |scope, template|
          path = [scope, "templates"] + state.command_path
          search_root.add_file(path, Valise::StringTools.align(template))
        end
      end

      def open(state)
        define_files(state)

        super
      end
    end
  end
end
