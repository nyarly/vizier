module Vizier
  module Renderers
    class Template < Base
      def initialize(format, template_files)
        @templates = {}
        @format = format
        @template_files = template_files
      end

      attr_reader :format, :template_files

      def template_inclusion(path)
        find_template(format, %w{includes} + path.split("/"))
        @template_files.find(%{includes} + path.split("/")).contents
      end

      def template_for_command(command)
        template_path = build_template_path(format, command.path)
        return find_template(format, template_path)
      end

      def build_template_path(path)
        return path + [ "#{format}.#{template_extension}" ]
      end

      def template_extension
        "sten"
      end

      def find_template(path)
        return @templates[[format, path]] ||=
          begin
            template_file = @template_files.find(path)
            Stencil::Template::string(template_file.contents, path, 1){|path| template_inclusion(format, path)}
          rescue Valise::PathNotFound, Valise::PathNotInRoot
            Stencil::Template::string(default_template(path)){|path| template_inclusion(format, path)}
          end
      end

      def default_template_hash
        { template_dir => default_template }
      end

      def default_template(path)
        "Template #{path.inspect} not defined.\n[;apply command_view /;]"
      end

      def render(command, view)
        template = template_for_command(format, command)
        template.render(view).chomp
      end
    end
  end
end
