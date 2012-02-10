require 'vizier/argument-decorators/base'

module Vizier
  module SubstringMatch
    ArgumentDecorator::register self, :substring_complete
    ArgumentDecorator::register self, :fuzzy_complete

    require 'strscan'
    class SubstringMatcher < Argument::CompletionMatcher
      def initialize(prefix, list, &block)
        super(prefix, list)
        bits = []
        scanner = StringScanner.new(prefix)
        until scanner.eos?
          bits.unshift scanner.scan(%r{[-./_]?.})
        end

        if block.nil?
          @validation_block = proc {|a| true}
        else
          @validation_block = proc &block
        end

        pattern = bits.inject do |pattern, bit|
          "#{Regexp::escape(bit)}((.*?)#{pattern})?"
        end

        pattern = pattern.nil? ? ".*" : "((.*?)" + pattern + ")?.*?"

        @regex = Regexp.new(pattern)
      end

      def mark_ranges(match_data)
        index_back = match_data[0].length

        ranges = []
        match_data[1..-1].each_slice(2).each_cons(2).map do |here, there|
          lit, between = *(here.map{|str| str.length})
          next_lit, next_between = *(there.map{|str| str.length})

          open = index_back - lit + between
          if ranges.last && ranges.last.last == open
            old = ranges.pop
            open = old.first
          end

          ranges << ((open)...(index_back - next_lit))
        end

        if match_data.length > 2
          open = index_back + match_data[-1].length - match_data[-2].length
          if ranges.last && ranges.last.last == open
            old = ranges.pop
            open = old.first
          end

          ranges << (open ... index_back)
        end


        ranges
      end


      def acceptable?(match_data, rating)
        return (not match_data[-1].nil? and @validation_block[match_data.string] and super)
      end

      def rate(m)
        return 0 if m.nil?
        return 10.0 * m.to_a.length / (m.string.length * 1.0)
      end
    end

    def completion_matcher(terms, prefix, list, subject)
      return SubstringMatcher.new(prefix, list) do |term|
        validate(term, subject)
      end
    end

    def self.included(other)
      if other.instance_methods(false).include?(:complete)
        mod = Module.new
        %w{complete state_consume}.each do |method_name|
          method = other.instance_method(method_name)
          mod.define_method(method_name, method)
        end
        other.include(mod)
      end
    end

    def complete(original_terms, prefix, subject)
      results = super
      fix_unselectable_shortest(original_terms, prefix, results, subject)
      results
    end

    #Might migrate out - not to Arg::Base but maybe to another deco
    def state_consume(state, subject)
      term = state.next_term || ""
      if validate(term, subject)
        state.arg_hash.merge!({@name => term})
        state.unsatisfied_arguments.shift
        return [state]
      elsif existing_matcher = @completion_matchers[term]
        best = existing_matcher.found.max{|left, right| left.rating <=> right.rating}
        if validate(best.text, subject)
          state.arg_hash.merge!({@name => best.text})
          state.unsatisfied_arguments.shift
          return [state]
        end
      end
      return []
    end

    #XXX I think this was a stab at dealing with the "shortest can't be chosen"
    #problem, now fixed by "best match is consumed" approach.  Might be
    #unnecessary.
    def fix_unselectable_shortest(terms, prefix, original, subject)
      list = original.list.dup
      shortest = list.min{|one, two| one.length <=> two.length}
      return if shortest.nil?
      list.delete(shortest)

      check_pattern = completion_matcher(terms, shortest, nil, subject)
      filter = restricted_pattern(prefix)
      if list.all?{|item| check_pattern =~ item and filter !~ item }
        original.list.replace [shortest]
      end
    end

    def restricted_pattern(prefix)
      split_pattern = /(.*#{Regexp.escape(fs)})?([^#{fs}]*)/
      m = split_pattern.match(prefix)

      if m[1].nil?
        Regexp.new(substring_pattern(m[2], "[^#{fs}]*?"))
      else
        Regexp.new(substring_pattern(m[1]) + substring_pattern(m[2], "[^#{fs}]*?"))
      end
    end

    def fs
      File::Separator
    end

    def substring_pattern(string, interleave=".*?")
      %{#{string.split(//).map{|ch| Regexp.escape(ch)}.join(interleave)}#{interleave}}
    end
  end
end
