module Vizier
  module VisitStates
    #Dumb, flat VisitState
    #Ideally, one class that doesn't know how to do anything, but calculate
    #values
    #Potentially subclassible for special cases.
    class VisitState
      def initialize(node)
        @command_path = []
        @node = node
        @parsed_tokens = []
      end

      #XXX: De-meta-ing: initialize_copy should take over for
      #@shared_attributes - super; #copy my attrs.
      def initialize_copy(original)
        @command_path = original.command_path.dup
        @parsed_tokens = original.parsed_tokens.dup
        @node = original.node
      end

      def <=>(other)
        other.priority <=> self.priority
      end

      def remaining
        []
      end

      def priority
        command_path.length
      end

      attr_accessor :node, :command_path
      attr_reader :parsed_tokens

      #XXX zap this
      alias change_node node=

        def inspect
          node_name = case @node
                      when nil
                        "<nil>"
                      else
                        @node.name
                      end
          "#{self.class}[#{("%x" % self.object_id)[-4..-1]}]@#{node_name} #{@parsed_tokens.inspect}"
        end
    end

    class CommandPath < VisitState
      def initialize(node, path)
        super(node)
        @term_list = path
      end

      attr_accessor :term_list

      def initialize_copy(original)
        super
        @term_list = original.term_list.dup
      end

      def advance_term
        term = @term_list.shift
        @parsed_tokens << term
        return term
      end

      def peek_term
        @term_list.first
      end

      def terms_complete?
        @term_list.empty?
      end

      def remaining
        @terms_list.inspect
      end

      def inspect
        super + "=> #{@terms_list.inspect}"
      end
    end

    require 'strscan'

    #Still torn about StringScanner vs MatchData
    class InputString< VisitState
      def initialize(node, input)
        super(node)
        @unparsed_input = StringScanner.new(input)
      end

      attr_reader :unparsed_input

      def initialize_copy(original)
        super
        @unparsed_input = original.unparsed_input.dup
      end

      def remaining
        @unparsed_input.rest
      end

      def inspect
        super + "=> #{@unparsed_input.rest.inspect}"
      end

      def term_regexp
        /^\s*(\S+)/
      end

      def terms_complete?
        check(/\s*/)
        @unparsed_input.post_match.empty?
      end

      def scan(*regexen)
        regexen.each do |regexp|
          next if @unparsed_input.scan(regexp).nil?
          term = @unparsed_input[1]
          @parsed_tokens << term
          return term
        end
        return nil
      end

      def advance_term
        scan(term_regexp)
      end

      def check(*regexen)
        regexen.each do |regexp|
          next if @unparsed_input.check(regexp).nil?
          return @unparsed_input[1]
        end
        return nil
      end

      def peek_term
        check(term_regexp)
      end

      def post_match
        @unparsed_input.post_match
      end
    end

    #XXX: set_nesting needs to die?
    class CommandArguments < InputString
      def initialize(node, input)
        super
        @unsatisfied_arguments = []
        @arg_hash = {}
        @set_nesting = [node]
      end

      attr_accessor :unsatisfied_arguments, :arg_hash
      attr_accessor :set_nesting

      def initialize_copy(original)
        super
        @unsatisfied_arguments = original.unsatisfied_arguments.dup
        @arg_hash = original.arg_hash.dup
        @set_nesting = original.set_nesting.dup
      end

      def has_arguments?
        !@unsatisfied_arguments.empty?
      end

      def first_argument
        @unsatisfied_arguments.first
      end

      def inspect
        super + " | #{@unsatisfied_arguments.inspect} #{@arg_hash.inspect}"
      end
    end

    #XXX Not sure if subject stays here or moves to InputParser
    class CommandInstantiator < CommandArguments
      def initialize(node, input)
        super
        @subject = nil
        @subject_context = []
      end
      attr_reader :subject, :subject_context

      def initialize_copy(original)
        super
        @subject_context = original.subject_context.dup
        @subject = original.subject
      end

      def command_instance(command_set, subject)
        @subject ||= subject
        command = @node.executable(self)
        p command
        return command
      end
    end
  end
end
