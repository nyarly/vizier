require 'vizier/dsl'
require 'vizier/arguments/base'

module Vizier
  class ArgumentDecorator
    include DSL::Argument

    class << self
      def register(who, name)
        DSL::Argument::register_decorator(who, name.to_s)
      end
      alias register_as register
    end

    def initialize(wrapped_by, wrap_with, &block)
      @wrapped_by = wrapped_by
      @wrap_with = wrap_with
    end

    def embed_argument(arg)
      case @wrap_with
      when Class
        @wrapped_by.embed_argument(@wrap_with.new(arg))
      when Module
        @wrapped_by.embed_argument(arg.extend @wrap_with)
      else
        raise "Tried to decorate an argument #{self.inspect} with #{@wrap_with.class.name}"
      end
    end
  end

  class ArgumentDecoration < Argument
    class << self
      def register(name)
        ArgumentDecorator::register(self, name)
      end
      alias register_as register
    end

    Argument.instance_methods(false).each do |method|
      class_eval(<<-EOM, __FILE__, __LINE__ + 1)
      def #{method}(*args, &block)
        decorated.#{method}(*args, &block)
      end
      EOM
    end

    def pretty_print_instance_variables
      ["@decorated"]
    end

    def initialize(down)
      @decorated = down
    end

    def decorated
      @decorated
    end

    def unwrap(mod)
      if has_feature?(mod)
        return decorated.unwrap(mod)
      else
        return self
      end
    end

    def has_feature?(mod)
      return true if self.kind_of? mod
      return decorated.has_feature(mod)
    end
    alias has_feature has_feature?

    def inspect
      "#{self.class.name.split("::").last}(#{decorated.inspect})"
    end
  end
end
