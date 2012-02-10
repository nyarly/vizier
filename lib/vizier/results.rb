require 'vizier/result-list'
require 'Win32/Console/ANSI' if RUBY_PLATFORM =~ /win32/
require 'thread'

module Kernel
  def puts(*args)
    $stdout.puts(*args)
  end
end


module Vizier
  class << self
    #Call anywhere to be sure that $stdout is replaced by an OutputStandin that
    #delegates to the original STDOUT IO.  This by itself won't change output behavior.
    #Requiring 'vizier' does this for you.  Multiple calls are safe though.
    def wrap_stdout
      return if $stdout.respond_to?(:add_dispatcher)
      $stdout = OutputStandin.new($stdout)
    end

    #If you need the actual IO for /dev/stdout, you can call this to get it.  Useful inside of
    #Results::Formatter subclasses, for instance, so that they can actually send messages out to
    #the user.
    def raw_stdout
      if $stdout.respond_to?(:__getobj__)
        $stdout.__getobj__
      else
        $stdout
      end
    end

    #See Vizier::wrap_stdout
    def wrap_stderr
      return if $stdout.respond_to?(:add_dispatcher)
      $stderr = OutputStandin.new($stderr)
    end

    #See Vizier::raw_stdout
    def raw_stderr
      if $stderr.respond_to?(:__getobj__)
        $stderr.__getobj__
      else
        $stderr
      end
    end
  end

  #Wraps an IO using DelegateClass.  Dispatches all calls to the IO, until a
  #Collector is registered, at which point, methods that the Collector
  #handles will get sent to it.
  class OutputStandin < IO
    def initialize(io)
      @_dc_obj = io
      unless io.fileno.nil?
        super(io.fileno,"w")
      end
    end

    def method_missing(m, *args)  # :nodoc:
      unless @_dc_obj.respond_to?(m)
        super(m, *args)
      end
      @_dc_obj.__send__(m, *args)
    end

    def respond_to?(m)  # :nodoc:
      return true if super
      return @_dc_obj.respond_to?(m)
    end

    def __getobj__  # :nodoc:
      @_dc_obj
    end

    def __setobj__(obj)  # :nodoc:
      raise ArgumentError, "cannot delegate to self" if self.equal?(obj)
      @_dc_obj = obj
    end

    def clone  # :nodoc:
      super
      __setobj__(__getobj__.clone)
    end

    def dup  # :nodoc:
      super
      __setobj__(__getobj__.dup)
    end

    methods = IO.public_instance_methods(false)
    methods -= self.public_instance_methods(false)
    methods |= ['class']
    methods.each do |method|
      begin
        module_eval <<-EOS
          def #{method}(*args, &block)
            begin
              @_dc_obj.__send__(:#{method}, *args, &block)
            rescue
              $@[0,2] = nil
              raise
            end
          end
        EOS
      rescue SyntaxError
        raise NameError, "invalid identifier %s" % method, caller(3)
      end
    end

    def thread_stack_index
      "standin_dispatch_stack_#{self.object_id}"
    end

    def relevant_collector
      Thread.current[thread_stack_index] ||
        Thread.main[thread_stack_index]
    end

    def define_dispatch_methods(dispatcher)# :nodoc:
      dispatcher.dispatches.each do |dispatch|
        (class << self; self; end).module_eval <<-EOS
          def #{dispatch}(*args)
            dispatched_method(:#{dispatch.to_s}, *args)
          end
        EOS
      end
    end

    def dispatched_method(method, *args)# :nodoc:
      collector = relevant_collector
      if not collector.nil? and collector.respond_to?(method)
        return collector.__send__(method, *args)
      end
      return __getobj__.__send__(method, *args)
    end

    def add_thread_local_dispatcher(collector)
      Thread.current[thread_stack_index]=collector
      define_dispatch_methods(collector)
    end
    alias set_thread_collector add_thread_local_dispatcher
    alias add_dispatcher add_thread_local_dispatcher
    alias set_default_collector add_dispatcher

    #Unregisters the dispatcher.
    def remove_dispatcher(dispatcher)
      if Thread.current[thread_stack_index] == dispatcher
        Thread.current[thread_stack_index] = nil
      end
    end

    alias remove_collector remove_dispatcher
    alias remove_thread_local_dispatcher remove_dispatcher
    alias remove_thread_collector remove_thread_local_dispatcher
  end

  #This is the output management module for CommandSet.  With an eye towards
  #being a general purpose UI library, and motivated by the need to manage
  #pretty serious output management, the Results module provides a
  #reasonably sophisticated output train that runs like this:
  #
  #0. An OutputStandin intercepts normal output and feeds it to ...
  #0. A Collector aggregates output from OutputStandins and explicit #item
  #   and #list calls and feeds to to ...
  #0. A Presenter handles the stream of output from Collector objects and
  #   emits +saw+ and +closed+ events to one or more ...
  #0. Formatter objects, which interpret those events into user-readable
  #   output.
  module Results
    #Collects the events spawned by dispatchers and sends them to the presenter.
    #Responsible for maintaining it's own place within the larger tree, but doesn't
    #understand that other Collectors could be running at the same time - that's the
    #Presenter's job.
    class Collector
      def initialize(presenter, list_root)
        @presenter = presenter
        @nesting = [list_root]
      end

      def initialize_copy(original)
        @presenter = original.instance_variable_get("@presenter")
        @nesting = original.instance_variable_get("@nesting").dup
      end

      def items(*objs)
        if Hash === objs.last
          options = objs.pop
        else
          options = {}
        end
        objs.each do |obj|
          item(obj, options)
        end
      end

      def item( obj, options={} )
        @presenter.item(@nesting.last, obj, options)
      end

      def begin_list( name, options={} )
        @nesting << @presenter.begin_list(@nesting.last, name, options)
        if block_given?
          yield
          end_list
        end
      end

      def end_list
        @presenter.end_list(@nesting.pop)
      end

      @dispatches = {}

      def self.inherited(sub)
        sub.instance_variable_set("@dispatches", @dispatches.dup)
      end

      def self.dispatches
        @dispatches.keys
      end

      def dispatches
        self.class.dispatches
      end

      #Use to register an IO +method+ to handle.  The block will be passed a
      #Collector and the arguments passed to +method+.
      def self.dispatch(method, &block)
        @dispatches[method] = true
        define_method(method, &block)
      end

      dispatch :puts do |*args|
        args.each do |arg|
          item arg
        end
      end

      dispatch :write do |*args|
        args.each do |arg|
          item arg
        end
      end

      dispatch :p do |*args|
        args.each do |arg|
          item(arg, :string => :inspect, :timing => :immediate)
        end
      end
    end

    #Gets item and list events from Collectors, and emits two kinds of
    #events to Formatters:
    #[+saw+ events] occur in chronological order, with no guarantee regarding timing.
    #[+closed+ events] occur in tree order.
    #
    #In general, +saw+ events are good for immediate feedback to the user,
    #not so good in terms of making sense of things.  They're generated as
    #soon as the relevant output element enters the system.
    #
    #On the other hand, +closed+ events will be generated in the natural
    #order you'd expect the output to appear in.  Most Formatter subclasses
    #use +closed+ events.
    #
    #A list which has not received a "list_end" event from upstream will
    #block lists later in tree order until it closes.  A Formatter that
    #listens only to +closed+ events can present them to the user in a way
    #that should be reasonable, although output might be halting for any
    #process that takes noticeable time.
    #
    class Presenter
      class Exception < ::Exception; end

      def initialize
        @results = List.new("")
        @leading_edge = @results
        @formatters = []
        @list_lock = Mutex.new
      end

      def create_collector
        return Collector.new(self, @results)
      end

      def register_formatter(formatter)
        @formatters << formatter
        formatter.notify(:start, nil)
      end

      def leading_edge?(list)
        return list == @leading_edge
      end

      def item( home, value, options={} )
        item = ListItem.new(value)

        add_item(home, item, options)

        notify(:saw, item)
        return nil
      end

      def begin_list( home, name, options={} )
        list = List.new(name)

        add_item(home, list, options)

        notify(:saw_begin, list)
        return list
      end

      def end_list( list )
        @list_lock.synchronize do
          list.close
          advance_leading_edge
        end

        notify(:saw_end, list)
        return nil
      end

      def done
        @results.close
        advance_leading_edge
        notify(:done, nil)
      end

      #Returns the current list of results.  A particularly advanced
      #Formatter might treat +saw_*+ events like notifications, and then use
      #the List#filter functionality to discover the specifics about the
      #item or list just closed.
      def output
        @results
      end

      protected
      def advance_leading_edge
        iter = ListIterator.new(@leading_edge.tree_order_next)
        iter.each do |forward|
          case forward
          when ListEnd
            break if forward.end_of.open?
            break if forward.end_of.name.empty?
            notify(:leave, forward.end_of)
          when List
            notify(:arrive, forward)
          when ListItem
            notify(:arrive, forward)
          end

          @leading_edge = forward
        end
      end

      def add_item(home, item, options)
        item.depth = home.depth + 1

        @list_lock.synchronize do
          #home = get_collection(path)
          item.options = home.options.merge(options)
          home.add(item)
          advance_leading_edge
        end
      end

      def notify(msg, item)
        @formatters.each do |f|
          f.notify(msg, item)
        end
      end
    end
  end
end
