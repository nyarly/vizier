require 'vizier/arguments/base'
module Vizier
  class ComplexArgument < Argument
    include DSL::Argument
    include ArgumentHost

    # initialize(embed_in){ yield if block_given? }
    def initialize(embed_in, &block)
      @wrapping_decorator = embed_in
      @subject_requirements = []
      @names = nil
      @name = nil
      @argument_list = []

      self.instance_eval &block
      @wrapping_decorator.embed_argument(self)
    end

    attr_accessor :argument_list, :subject_requirements

    def names
      return @names ||=
        begin
          @argument_list.inject([@name]) do |list, argument|
            list + [*argument.name]
          end.compact
        end
    end

    def inspect
      "#{self.class.name.split("::").last}:#{@name}(#{@argument_list.inspect})"
    end

    def name(name = nil)
      if name.nil?
        return names
      else
        @name = name.to_s
      end
    end

    def omittable?
      return argument_list.inject(false) do |can_omit, sub_arg|
        can_omit || sub_arg.omittable?
      end
    end

    def subject_requirements
      argument_list.inject([]) do |list, arg|
        list + arg.subject_requirements
      end
    end

    #If a hash is used for arguments that includes more than one of
    #alternating argument's sub-arguments, the behavior is undefined
    def consume_hash(subject, hash)
      result = @argument_list.inject({}) do |result, arg|
        result.merge arg.consume_hash(subject, hash)
      end
      unless @name.nil?
        result[@name] = parse(subject, hash[@name])
      end
      return result
    end
  end
end
