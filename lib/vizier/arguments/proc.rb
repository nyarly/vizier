require 'vizier/arguments/base'

module Vizier
  #Created with a two argument block, a proc_argument validates it's input
  #by passing it to the block.  It also uses the block to validate.
  #
  #As a result, the block should return a list of acceptable completions,
  #given a prefix and the current subject.
  #
  #Ideally, use proc_arguments to prototype new argument types before
  #creating whole classes for them.
  class ProcArgument < Argument
    register "proc", Proc

    def initialize(name, prok)
      raise TypeError, "Block not arity 2: #{prok.arity}" unless prok.arity == 2
      super(name, nil)
      @process = proc &prok
    end

    def complete(terms, prefix, subject)
      return Orichalcum::CompletionResponse.create(@process.call(prefix, subject))
    end

    def validate(term, subject)
      return @process.call(term, subject).include?(term)
    end
  end

  #Like ProcArgument, but performs to validation on the input.
  class NoValidateProcArgument < ProcArgument
    register "nonvalidating_proc"

    def validate(term, subject)
      return true
    end
  end
end
