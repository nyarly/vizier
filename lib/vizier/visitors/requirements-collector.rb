require 'vizier/visitors/base'

module Vizier
  module Visitors
    class RequirementsCollector < Collector
      def initialize(subject)
        super
        @subject = subject
      end

      attr_reader :subject

      def open(state)
        @subject.required_fields(state.node.subject_requirements.uniq)
        state.node.argument_list.each do |argument|
          @subject.required_fields(argument.subject_requirements.uniq)
        end
        super
      end
    end
  end
end
