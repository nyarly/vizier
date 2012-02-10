require 'vizier/argument-decorators/base'

module Vizier
  class Settable < ArgumentDecoration
    register_as "settable"

    def subject_requirements
      decorated.subject_requirements + [:knobs]
    end

    def state_complete(state, subject)
      Orichalcum::NullCompletion.singleton
    end

    #XXX This means "I can be missing"
    #We might need "I can be present"
    def required?
      false
    end

    def completing_states(state)
      state.unsatisfied_arguments.shift
      [ state ]
    end

    def consume_hash(subject, hash)
      result = {}
      [*names].each {|name|
        result[name] = hash[name]
      }
      result
    end

    def state_consume(state, subject)
      thumb = subject.knobs
      path = state.command_path.dup
      path.each do |segment|
        return [] unless thumb.has_key?(segment)
        thumb = thumb[segment]
      end
      thumb = thumb[self.name]
      state.arg_hash.merge! self.name => thumb
      state.unsatisfied_arguments.shift
      return [state]
    end
  end
end
