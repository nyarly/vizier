require 'vizier/arguments/complex'
module Vizier
  #Allows several arguments to share a position.  Pass a block to the
  #"decorator" method with the argument declarations inside.  The first
  #argument that can parse the input will be assigned - others will get nil.
  class AlternatingArgument < ComplexArgument
    def state_complete(state, subject)
      Orichalcum::NullCompletion.singleton
    end

    def completing_states(state, subject)
      state_consume(state, subject)
    end

    def state_consume(state, subject)
      match = state.check(*consume_regexen)
      if match.nil?
        term=""
      else
        term = match[1]
      end
      state.arg_hash.merge!({@name => term}) unless @name.nil?
      state.unsatisfied_arguments.shift

      return argument_list.map do |arg|
        newstate = state.dup
        newstate.unsatisfied_arguments.unshift(arg)
        newstate
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

    def parse(subject, term)
      catcher = first_catch(term, subject)
      return catcher.parse(subject, term)
    end
    private


    def first_catch(term, subject)
      catcher = argument_list.find do |sub_arg|
        sub_arg.validate(term, subject)
      end

      return catcher
    end
  end
end
