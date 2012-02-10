module Vizier
  #An overworked exception class.  It captures details about the command
  #being interrupted as it propagates up the stack.
  class ResumeFrom < ::Exception
    def initialize(pause_deck, msg = "")
      super(msg)
      @setup = Visitors::CommandSetup.new(nil)
      @pause_deck = pause_deck
    end

    attr_reader :setup, :pause_deck
  end

  class ResumeFromOnlyThis < ResumeFrom; end

  class CommandError < ScriptError; end

  class Exception < StandardError; end

  class CantMergeArguments < StandardError
    def initialize(first, second)
      @first, @second = first, second
      super("Cannot merge #{first.inspect} with #{second.inspect}")
    end
  end

  class CommandException < Exception
    def initialize(msg=nil)
      super
      @raw_input = nil
      @command = nil
    end

    def message
      if @command.nil?
        if @raw_input.nil?
          super
        else
          return @raw_input.inspect() +": "+ super
        end
      else
        return @command.path.join(" ") +": "+ super
      end
    end

    attr_accessor :raw_input, :command
  end

  class ArgumentInvalidException < CommandException
    def initialize(pairs)
      @pairs = pairs.dup
      super("Invalid arguments: #{pairs.map{|n,v| "#{n}: #{v.inspect}"}.join(", ")}")
    end

    attr_reader :pairs
  end

  class OutOfArgumentsException < CommandException; end
  class ArgumentUnrecognizedException < CommandException; end

  class CompletionTimeout < Exception; end
  class CompletionLimitReached < Exception; end
end
