require 'forwardable'

module Vizier
  module Results
    #The end of the Results train.  Formatter objects are supposed to output to the user events that they
    #receive from their presenters.  To simplify this process, a number of common IO functions are delegated
    #to an IO object - usually Vizier::raw_stdout.
    #
    #This class in particular is pretty quiet - probably not helpful for everyday use.
    #Of course, for some purposes, singleton methods might be very useful
    class Formatter
      module Styler
        Foregrounds = {
          'black'   => 30,
          'red'     => 31,
          'green'   => 32,
          'yellow'  => 33,
          'blue'    => 34,
          'magenta' => 35,
          'cyan'    => 36,
          'white'   => 37
        }

        Backgrounds = {}

        Foregrounds.each() do |name, value|
          Backgrounds[name] = value + 10
        end

        Extras = {
          'clear'     => 0,
          'bold'      => 1,
          'underline' => 4,
          'reversed'  => 7
        }

        def style(text, options)
          options ||= {}
          if options.key? :format_advice
            options = options.merge(options[:format_advice])
          end
          aliased = {
            :foreground => options[:color],
            :extra => options[:text_style]
          }
          options = aliased.merge(options)
          markup = code_for(Foregrounds, options[:foreground]) +
            code_for(Backgrounds, options[:background]) +
            code_for(Extras, options[:extra])
          return text if markup.empty?
          return markup + text + code_for(Extras, "clear")
        end

        def code_for(kind, name)
          if kind.has_key?(name.to_s)
            "\e[#{kind[name.to_s]}m"
          else
            ""
          end
        end
      end
      extend Forwardable

      class FormatAdvisor
        def initialize(formatter)
          @advisee = formatter
        end

        def list(&block)
          @advisee.advice[:list] << proc(&block)
        end

        def item(&block)
          @advisee.advice[:item] << proc(&block)
        end

        def output(&block)
          @advisee.advice[:output] << proc(&block)
        end
      end

      def notify(msg, item)
        if msg == :start
          start
          return
        end
        if msg == :done
          finish
          return
        end

        apply_advice(item)

        if List === item
          case msg
          when :saw_begin
            saw_begin_list(item)
          when :saw_end
            saw_end_list(item)
          when :arrive
            closed_begin_list(item)
          when :leave
            closed_end_list(item)
          end
        else
          case msg
          when :arrive
            closed_item(item)
          when :saw
            saw_item(item)
          end
        end
      end

      def initialize()
        @advisor = FormatAdvisor.new(self)
        @advice = {:list => [], :item => [], :output => []}
      end

      def apply_advice(item)
        type = List === item ? :list : :item

        item.options[:format_advice] =
          @advice[type].inject(default_advice(type)) do |advice, advisor|
          result = advisor[item]
          break if result == :DONE
          if Hash === result
            advice.merge(result)
          else
            advice
          end
          end
      end

      attr_reader :advice

      def receive_advice(&block)
        @advisor.instance_eval(&block)
      end

      def default_advice(type)
        {}
      end

      #Presenter callback: output is beginning
      def start; end

      #Presenter callback: a list has just started
      def saw_begin_list(list); end

      #Presenter callback: an item has just been added
      def saw_item(item); end

      #Presenter callback: a list has just ended
      def saw_end_list(list); end

      #Presenter callback: a list opened, tree order
      def closed_begin_list(list); end

      #Presenter callback: an item added, tree order
      def closed_item(item); end

      #Presenter callback: an list closed, tree order
      def closed_end_list(list); end

      #Presenter callback: output is done
      def finish; end
    end

    #The simplest useful Formatter: it outputs the value of every item in tree
    #order.  Think of it as what would happen if you just let puts and p go
    #directly to the screen, without the annoying consequences of threading,
    #etc.
    class TextFormatter < Formatter
      def initialize(out = nil, err = nil)
        @out_to = out || ::Vizier::raw_stdout
        @err_to = err || ::Vizier::raw_stderr
        super()
      end

      def_delegators :@out_to, :p, :puts, :print, :printf, :putc, :write, :write_nonblock, :flush

      def self.inherited(sub)
        sub.extend Forwardable
        sub.class_eval do
          def_delegators :@out_to, :p, :puts, :print, :printf, :putc, :write, :write_nonblock, :flush
        end
      end

      def closed_item(value)
        puts value
      end
    end
  end
end
