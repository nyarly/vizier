require 'vizier/formatter/base'

module Vizier::Results
    class StrategyFormatter < TextFormatter
      class FormatStrategy
        extend Forwardable
        include Formatter::Styler

        def initialize(name, formatter)
          @name = name
          @formatter = formatter
          setup
        end

        def setup; end

        def_delegators :@formatter, :p, :puts, :print, :printf, :putc, :write, :write_nonblock, :flush

        attr_reader :name

        def switch_to(name)
          unless name == self.name
            return true
          end
          return false
        end

        def finish
          @formatter.pop_strategy(self.name)
        end

        #Presenter callback: a list has just started
        def saw_begin_list(list); end

        #Presenter callback: an item has just been added
        def saw_item(item); end

        #Presenter callback: a list has just ended
        def saw_end_list(list); end

        #Presenter callback: a list opened, tree order
        def closed_begin_list(list);
        end

        #Presenter callback: an item added, tree order
        def closed_item(item); end

        #Presenter callback: an list closed, tree order
        def closed_end_list(list);
          if list.options[:strategy_start] == self
            finish
          end
        end

        private
        def out
          @formatter.out_to
        end

        def err
          @formatter.err_to
        end
      end

      @strategies = {:default => FormatStrategy}

      class << self
        def strategy(name, base_klass = FormatStrategy, &def_block)
          @strategies[name.to_sym] = Class.new(base_klass, &def_block)
        end

        def inherited(sub)
          self.instance_variables.each do |var|
            value = self.instance_variable_get(var)
            if value.nil?
              sub.instance_variable_set(var, nil)
            else
              sub.instance_variable_set(var, value.dup)
            end
          end
        end

        def strategy_set(formatter)
          set = {}
          @strategies.each_pair do |name, klass|
            set[name] = klass.new(name, formatter)
          end
          return set
        end
      end

      def initialize(out = nil, err = nil)
        super(out, err)
        @strategies = self.class.strategy_set(self)
        @strategy_stack = [@strategies[:default]]
      end

      attr_reader :out_to, :err_to

      def_delegators :current_strategy, :saw_begin_list, :saw_item,
        :saw_end_list

      def current_strategy
        @strategy_stack.last
      end

      def push_strategy(name)
        if @strategies.has_key?(name)
          @strategy_stack.push(@strategies[name])
        end
      end

      def pop_strategy(name)
        if current_strategy.name == name
          @strategy_stack.pop
        end
      end

      def closed_begin_list(list)
        going_to = current_strategy.name
        unless list.options[:format_advice].nil? or
          (next_strategy = list.options[:format_advice][:type]).nil? or
          @strategies[next_strategy].nil? or
          not current_strategy.switch_to(next_strategy)
          going_to = next_strategy
        end
        push_strategy(going_to)
        current_strategy.closed_begin_list(list)
      end

      def closed_end_list(list)
        current_strategy.closed_end_list(list)
        current_strategy.finish
      end

      def closed_item(item)
        unless item.options[:format_advice].nil? or
          (once = item.options[:format_advice][:type]).nil? or
          @strategies[once].nil? or
          not current_strategy.switch_to(once)
          @strategies[once].closed_item(item)
        else
          current_strategy.closed_item(item)
        end
      end

      strategy :default do
        def closed_item(value)
          puts value
        end
      end

      strategy :progress do
        def switch_to(name); false; end
        def closed_begin_list(list)
          puts unless list.depth == 0
          justify = 0 || list[:format_advice][:justify]
          print style(list.to_s.ljust(justify), list.options)
        end

        def closed_item(item)
          print style(".", item.options)
          flush
        end

        def closed_end_list(list)
          puts
          super
        end
      end

      strategy :indent do
        def setup
          @indent_level = 0
        end

        def indent
          return "  " * @indent_level
        end

        def closed_begin_list(list)
          super
          puts indent + style(list.to_s, list.options)
          @indent_level += 1
          @indent_level
        end

        def closed_item(item)
          item.to_s.split(/\s*\n\s*/).each do |line|
            puts indent + style(line, item.options)
          end
          super
        end

        def closed_end_list(list)
          @indent_level -= 1
          @indent_level
          super
        end
      end

      strategy :invisible do
        def closed_item(value); end
      end

      strategy :skip do
        def closed_begin_list(list)
          finish
        end
      end

      strategy :chatty do
        def switch_to(name); false; end

        def saw_begin_list(list)
          err.print style("B", list.options)
        end

        def saw_item(list)
          err.print style(".", list.options)
        end

        def saw_end_list(list)
          err.print style("E", list.options)
        end

        def closed_begin_list(list);
          clean_options = list.options.dup
          clean_options.delete(:strategy_start)
          puts "> #{list.to_s} (depth=#{list.depth} #{clean_options.inspect})"
        end
        def closed_item(list)
          puts "  " + list.to_s +
            unless(list.options.empty?)
              " " + list.options.inspect
            else
              ""
            end
        end
        def closed_end_list(list); puts "< " + list.to_s; end
      end
    end
end
