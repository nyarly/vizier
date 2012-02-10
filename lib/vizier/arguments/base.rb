require 'vizier/dsl'
require 'orichalcum/completion-response'

module Vizier
  #XXX: module Arguments
  module ArgumentHost
    attr_reader :subject_requirements, :argument_list,
      :advice_block, :context

    def embed_argument(arg)
#      unless argument_list.last.nil? or argument_list.last.required?
#        if arg.required?
#          raise NoMethodError, "Can't define required arguments after optionals"
#        end
#      end

      self.subject_requirements += arg.subject_requirements

      argument_list << arg
    end

    #XXX deprecate
    def optional_argument(arg, values=nil, &get_values)
      optional.argument(arg, values, &get_values)
    end
  end

  #An Argument has a name and a value.  They're used to to validate input,
  #provide input prompts like tab-completion or pop-up menus.
  class Argument

    class << self
      #Used for new Argument subclasses to register the types they can be
      #based on, and the explicit names of the arguments
      #XXX: this will want to have a YARD adapter written for it
      def register(shorthand, type=nil)
        register_shorthand(shorthand)
        unless type.nil?
          register_type(type)
        end
      end

      def shorthand_module
        return @@shorthand_module ||= Module.new
      end

      #XXX: this will want to have a YARD adapter written for it
      def register_shorthand(shorthand, &method_def)
        method_def ||= default_shorthand_method
        shorthand_module.instance_eval do
          define_method(shorthand + "_argument", &method_def)
        end
        DSL::Argument::add_shorthand_module(shorthand_module)
      end

      def default_shorthand_method
        klass = self
        return lambda do |name, basis = nil, &prok|
          basis ||= prok
          arg = klass.new(name, basis)
          return self.embed_argument(arg)
        end
      end

      #XXX: WTF?
#      def add_shorthand(shorthand_method)
#      end

      #XXX: this will want to have a YARD adapter written for it
      def register_type(type)
        DSL::Argument::register_argument_for_type(self, type)
      end
    end


    def initialize(name, basis=nil)
      @name = name.to_s
      @basis = basis
      #XXX This might be a real issue at some point in the future.  Solution
      #isn't exactly clear atm.
      @completion_matchers = {}
    end

    attr_reader :name

    def names
      return [name()]
    end

    def inspect
      "#{self.class.name.split("::").last}:#{@name}"
    end

    def basis(subject = nil)
      return @basis unless DSL::Argument::SubjectDeferral === @basis
      return @basis.realize(subject)
    end

    def merge(other)
      half_merge(other)
    rescue CantMergeArguments
      other.half_merge(self)
    end

    def subject_requirements
      if DSL::Argument::SubjectDeferral === @basis
        return @basis.subject_requirements
      else
        return []
      end
    end

    #Validates the input string against the type of the argument.  Returns
    #true if the input is valid, or else false
    def validate(term, subject)
      raise NotImplementedError, "validate not implemented in #{self.class.name}"
    end

#    #Pulls strings from an ordered list of inputs and provides the parsed
#    #data to the host command Returns the parsed data or raises
#    #ArgumentInvalidException
#    def consume(subject, arguments)
#      term = arguments.shift
#      unless validate(term, subject)
#	raise ArgumentInvalidException, {@name => term}
#      end
#      return {@name => term}
#    end

    def complete_regexen
      @complete_regexen ||=
        begin
          quoted = /\A\s*((['"])(?:(?!\2).)*(?:\2)?)/
          unquoted = /\A\s*(\S+)/
          [quoted, unquoted]
        end
    end

    def consume_regexen
      @consume_regexen ||=
        begin
          quoted = /\A\s*((['"])(?:(?!\2).)*\2)/
          unquoted = /\A\s*(\S+)/
          [quoted, unquoted]
        end
    end

    def completion_prefix(state)
      state.check(*complete_regexen).sub(/\A['"]/, "")
    end

    def advance_term(state)
      state.scan(*consume_regexen)
    end

    #XXX rename => consume_state
    def state_consume(state, subject)
      term = nil
      term = advance_term(state)
      if term.nil?
        return [] #or state.make_invalid!
      end

      if validate(term, subject)
        term = term
        state.arg_hash.merge!({@name => term})
        state.unsatisfied_arguments.shift
        return [state]
      else
        return []
      end
    end

    class CompletionMatcher
      def initialize(prefix, list)
        @regex = %r{^#{prefix}.*}
        @prefix = prefix
        @match_threshhold = 0.9
        @list = list
        @found = []
        @done = false
        @mark_range = (0...prefix.length)
      end

      attr_accessor :match_threshhold
      attr_reader :found

      def mark_ranges(item)
        [@mark_range]
      end

      def acceptable?(match_data, rating)
        return rating > @match_threshhold
      end

      def find_completions()
        return if @done
        @list.each do |item|
          match_data = @regex.match(item)
          rating = self.rate(match_data)
          if acceptable?(match_data, rating)
            @found << Orichalcum::MarkedText.new(item, rating, mark_ranges(match_data))
          end
          rating
        end
        @done = true
      end

      def response
        response = Orichalcum::CompletionResponse.new(@found)
        response.prefix = @prefix
        if not @done
          response.add_hint("...")
        end
        return response
      end

      def each_match()
      end

      def rate(match_data)
        match_data.nil? ? 0 : 1
      end
    end

    def possible_completions(prefix, subject)
      basis(subject)
    end

    def completion_matcher(terms, prefix, list, subject)
      return CompletionMatcher.new(prefix, list)
    end

    require 'timeout'
    CompletionDeadline = 0.5

    #Provides a list of completion options based on a string prefix and the
    #subject The completion should be an array of completion options.  If
    #the completions have a common prefix, completion will enter it for the
    #user.  As a clever trick for providing hints: [ "This is a hint", "" ]
    def complete(original_terms, prefix, subject)
      #cache isn't valid of the basis changes
      list = possible_completions(prefix, subject)
      matcher = @completion_matchers[prefix] ||= completion_matcher(original_terms, prefix, list, subject)

      begin
        Timeout::timeout(CompletionDeadline) do
          matcher.find_completions
        end
      rescue Timeout::Error
        #That's ok.
      end

      return matcher.response
    end

    def state_complete(state, subject)
      terms = state.parsed_tokens.dup

      term = completion_prefix(state) || ""

      complete(terms, term, subject)
    end

    def completing_states(state, subject)
      []
    end

    def consume_hash(subject, hash)
      unless((term = hash[name]).nil?)
        if validate(term, subject)
          return {name => parse(subject, term)}
        else
          raise ArgumentInvalidException, {name => term}
        end
      end
      return {}
    end

    def check_present(keys)
      unless keys.include?(@name)
        raise OutOfArgumentsException, "Missing argument: #@name!"
      end
    end

    def unwrap(mod)
      return self #error if I still have the feature?
    end

    def has_feature?(mod)
      #TODO: memoization
      self.kind_of? mod
    end
    alias has_feature has_feature?

    #Used in completion to recognize that some arguments can be skipped
    def omittable?
      false
    end

    #Used in validation to require some arguments, and allow others to be
    #optional
    def required?
      true
    end

    #Returns the parsed data equivalent of the string input
    def parse(subject, term)
      return term
    end

    class SortConflict < Exception; end

    def self.sorting_features
      [
        Settable,
        Optional,
        Repeating
      ]
    end

    def <=>(other)
      self.class.sorting_features.each do |feature|
        case [has_feature?(feature), other.has_feature(feature)]
        when [true, false]
          1
        when [false, true]
          return -1
        end
      end
      return 0
    end

    protected

    def half_merge(other)
      if other.class === self and basis_can_replace(other.raw_basis)
        return self
      else
        raise CantMergeArguments, self, other
      end
    end

    def raw_basis
      @basis
    end

    def basis_can_replace(other_basis)
      @basis == other_basis
    end
  end
end
