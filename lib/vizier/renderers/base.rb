module Vizier
  module Renderers
    class Base
      def initialize
        @views = []
      end

      def render(command, output_view)
        @views << output_view
      end
    end
  end
end
