require 'vizier/argument-decorators/base'
module Vizier
  #Consumes several positions with the decorated argument.
  #  repeating.file_argument :some_files
  #
  #  > do_thing_to files/one.txt files/two.txt files/three.txt
  #
  #Will collect an array into +some_files+ of validated files.
  class Repeating < ArgumentDecoration
    register "repeating"
    register "many"

    def state_consume(state, subject)
      memo = state.arg_hash[:repeat_memo] || Hash.new{|h,k| h[k] = []}
      names.each do |nm|
        if state.arg_hash.has_key?(nm) and not memo[nm].last.equal? state.arg_hash[nm]
          if Array === state.arg_hash[nm] and not memo.has_key?(nm)
            memo[nm] = state.arg_hash[nm]
          else
            memo[nm] += [*state.arg_hash[nm]]
          end
          state.arg_hash.delete(nm)
        end
      end

      without = state.dup
      without.arg_hash.delete(:repeat_memo)
      memo.each_pair do |name,value|
        without.arg_hash[name] = value
      end
      without.unsatisfied_arguments.shift

      state.arg_hash[:repeat_memo] = memo
      state.unsatisfied_arguments.unshift(decorated)
      return [state, without]
    end

    def merge_hashes(into, outfrom)
      outfrom.each_pair do |key, value|
        if into.has_key?(key)
          into[key] = [*(into[key])] + [*value]
        else
          into[key] = [*value]
        end
      end
      into
    end

    def consume_hash(subject, hash)
      result = [*names].inject({}) do |arg_hash, name|
        terms = hash[name]
        if terms.nil?
          arg_hash
        else
          [*terms].inject(arg_hash) do |a_h, term|
            merge_hashes(a_h, decorated.consume_hash(subject, {name => term}))
          end
        end
      end
      return result
    end
  end
end
