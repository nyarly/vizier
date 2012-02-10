require 'vizier/arguments/base'
module Vizier
  #Using FiddlyArguments is sometimes unavoidable, but it kind of stinks.
  #You assign blocks that validate, complete and parse the input.  You're
  #probably better off subclassing Argument.
  #
  #n.b. that FiddlyArguments can't use the +subject+ keyword to use the
  #application state as their basis
  class FiddlyArgument < Argument
    def initialize(name, block)
      super(name, nil)

      (class << self; self; end).class_eval &block
    end

    def self.completion(&block)
      raise TypeError unless block.arity == 2
      define_method :complete, &block
    end

    def self.validation(&block)
      raise TypeError unless block.arity == 2
      define_method :validate, &block
    end

    def self.parser(&block)
      raise TypeError unless block.arity == 2
      define_method :parse, &block
    end
  end
end
