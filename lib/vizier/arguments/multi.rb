require 'vizier/arguments/base'
module Vizier
  #Consumes multiple words as dictated by the block used to create the
  #argument.  A little complex, but powerful.  For use, see
  #StandardCommands::Set
  class MultiArgument < Argument
    class MultiProcessor
      def initialize(terms, next_term, subject)
        @accepting = true
        @completions = []
        @terms = terms
        @next_term = next_term
        begin
          @completions = process(terms, next_term, subject)
        rescue Object => ex
#          ::Vizier::raw_stdout.puts [:MP_ex, ex.class, ex.message,
          #          ex.backtrace.first].inspect
        end
      end
      attr_reader :terms, :next_term, :completions

      def unacceptable
        @accepting = false
      end

      # This set of terms + last term is an acceptible result
      def accepting?
        return @accepting
      end

      # This set of terms + last term can accept more input
      def valid?
        return (not (@completions.nil? or @completions.empty?))
      end
    end

    register_shorthand "multiword", do |name, &prok|
      return self.embed_argument(MultiArgument.new(name, prok))
    end

    def initialize(name, prok)
      super(name,nil)
      case prok.arity
      when -1
        @processor = Class.new(MultiProcessor, &prok)
      when 3
        @processor = Class.new(MultiProcessor) do
          define_method(:process, prok)
        end
      else
        raise TypeError, "Block arity is #{prok.arity}, not 0 or 3"
      end
    end

    def validate(terms, subject)
      processed = @processor.new(terms[0...-1], terms.last, subject)
      return processed.valid?
    end

    def do_process(state)
      terms = state.arg_hash[@name]
      terms = terms.dup

      processed = @processor.new(terms, state.next_term, subject)
    end


    def state_consume(state, subject)
      state.arg_hash[@name] ||= []
      shifted = state.dup

      processed = do_process(state, subject)

      next_states = []

      if processed.accepting?
        shifted.unsatisfied_arguments.shift
        next_states << shifted
      end

      if processed.valid?
        if not processed.next_term.nil?
          state.arg_hash[@name] = processed.terms + [processed.next_term]

          next_states << state.dup
        end
      end

      return next_states
    end

    def completing_states(state, subject)
      state_consume(state, subject)
    end

    def state_complete(state, subject)
      state.arg_hash[@name] ||= []
      processed = do_process(state, subject)
      completions = processed.completions

      return Orichalcum::CompletionResponse.create(completions || [])
    end

    #XXX: used?
    def consume(subject, arguments)
      value = []
      until arguments.empty? do
        trying = arguments.shift
        if(validate(value + [trying], subject))
          value << trying
        else
          arguments.unshift(trying)
          break
        end
      end
      return {@name => value}
    end
  end
end
