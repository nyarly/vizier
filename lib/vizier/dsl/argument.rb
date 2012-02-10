module Vizier
  module DSL
    #The meta-programmatic machinery to create arguments quickly.  Includes
    #methods such that argument classes can register themselves into the DSL.
    #Much of this module is unfortunately obtuse - it's designed so that
    #argument types can be easily extended, which makes the actual DSL
    #trickier to document.
    #
    #Ultimately, arguments are governed by their basic type (which descends
    #from Argument) and the ArgumentDecorator objects that wrap it.
    #
    #Within a Command#setup block, you can make
    #decorator and argument calls like:
    #
    #  optional.named.string_argument :person, "A Person"
    #
    #Which will create a StringArgument and wrap it in the NamedArgument and
    #OptionalArgument ArgumentDecorators.  This sounds confusing, but the
    #upshot is that the +person+ argument can be omitted, but if it's
    #included, it must be preceded with the argument's name: "person" like
    #so:
    #  > command person judson
    #
    #Which will assign "judson" to the +person+ argument for the command.
    #
    #:include: doc/argumentDSL
    module Argument
      class SubjectDeferral
        def method_missing(name, *args, &block)
          @deferred_calls << [name, args, block]
          return self
        end

        def initialize
          @deferred_calls = []
        end

        def subject_requirements
          return [@deferred_calls.first.first]
        end

        def realize(subject)
          return @deferred_calls.inject(subject) do |obj, call|
            obj = obj.__send__(call[0], *call[1])
            if call[2].nil?
              obj
            else
              call[2].call(obj)
            end
          end
        end
      end

      @@decorator_map={}
      #The ArgumentDecorator#register method calls back to this, so that
      #decorators can quickly register a method to wrap an argument with
      #themselves.
      def self.register_decorator(klass, method)

        @@decorator_map[method] = klass
        define_method method do
          create_decorator(method)
        end
      end

      @@argmap={}
      #The Argument#register method calls back to this, which creates
      #methods like +funky_argument+ that are responsible for embedding the
      #actual arguments in the Commands they're declared for.
      def self.register_argument_for_type(klass, type)
        unless @@argmap.has_key?(type)
          @@argmap[type]=klass
        else
          warn "Argument class #{@@argmap[type].inspect} already registered for #{type.inspect}"
        end
      end

      def self.add_shorthand_module(mod)
        return if self < mod
        include(mod)
      end

      #Generates rdoc ready documentation of the decorator and argument
      #methods created by #register calls.  Output is included in this
      #module's documentation.  Also useful if you want to document your own
      #argument class' contributions.  Try something like:
      #
      #  > ruby -r"lib/vizier/arguments.rb" -e "puts Vizier::DSL::Argument::document"
      def self.document
        docs = <<-EOD
        There are two kinds of methods available for #{self.name}.
        First there are decorators.  They mark up arguments with extra
        meaning, like being optional.  The second are actual argument
        creation calls, which are shorthand for something like
          argument FiddlyArgument {}

        In general, you'll use these something like

          decorator.decorator.shorthand_argument "name"

        For instance

          named.optional.file_argument "config"

        Decorator methods, and the classes they add:

        EOD

        @@decorator_map.each_pair do |method, klass|
          docs += "+#{method}+:: #{klass.name.sub("Vizier::","")}\n"
        end

        docs += <<-EOD

        Don't forget about #alternating_argument and #argument itself!
        EOD

        indent = /^\s+/.match(docs)[0]
        docs.gsub!(/^#{indent}/, "")

        return docs
      end

      def self.argument_typemap #:nodoc:
        @@argmap
      end

      #When an ArgumentDecorator calls self.register, this method is aliased
      #with the name the decorator passes
      #It takes care of instantiating the
      #decorator such that it's available to decorate the eventual argument.
      #
      #Don't look to closely at the source.  It does bad things.
      def create_decorator(me)
        if block_given?
          return ArgumentDecorator.new(self, @@decorator_map[me]) do |args|
            yield(*args)
          end
        else
          return ArgumentDecorator.new(self, @@decorator_map[me])
        end
      end

      #The basic argument definition.  If +arg+ is an Argument object, it'll
      #be used - which means that you can explicitly create and argument and
      #embed it.  Otherwise, the values of +values+ or +get_values+ will be
      #used to create the argument
      def argument(arg, *values, &get_values)
        name = nil
        argument = nil
        if(::Vizier::Argument === arg)
          name = arg.name
          argument = arg
        elsif(Class === arg and ::Vizier::Argument > arg)
          argument = arg.new(values[0], get_values||values[1])
        else
          name = arg
          argument = create(name, get_values||values.first)
        end

        return self.embed_argument(argument)
      end

      #Returns a SubjectDeferral  Ultimately, this allows you to reference
      #and base an argument on a value in the subject.  Check this out:
      #
      #  number_argument :which_little_pig subject.pigs {|pigs| 1..pigs.length}
      #
      #When that argument is evaluated, the pigs (is_a? Array) field of
      #the subject will get turned into a range: from 1 to it's length.
      def subject
        return SubjectDeferral.new
      end

      #Sugar for creating an alternating argument.  Basically, an
      #alternating argument is a series of arguments, any of which could be
      #set.  They either need to be of distinct types, or use +named+ to
      #distinguish between them.
      def alternating_argument(name=nil, &block)
        arg = AlternatingArgument.new(self, &block)
        arg.name(name)
      end

      alias alternating alternating_argument

      def concatenated_argument(name=nil, &block)
        arg = ConcatenatedArgument.new(self, &block)
        arg.name(name)
      end

      alias concatenated concatenated_argument
      alias grouped concatenated_argument

      #The method used to instantiate arguments based on their values.
      #Searches all registered Argument classes, from children up, until one
      #admits to being able to create arguments based on the value.
      def create(name, basis)
        @@argmap.keys.sort{|r,l|(r>l)?1:-1}.each do |type| #Check child classes first
          if type === basis
            return @@argmap[type].new(name, basis)
          end
        end
        raise TypeError, "Don't know how to base an argument " +
                         "on #{basis.class}"
      end

      def named_optionals #:nodoc:
        raise NotImplementedException
      end
    end
  end
end
