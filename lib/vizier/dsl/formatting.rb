
module Vizier
  module DSL

    #The DSL for formatting.  A lot of code will do just fine with the
    #Kernel#puts #that Results intercepts.  More involved output control
    #starts by including CommandSet::DSL::Formatting, and using
    #Formatting#list and Formatting#item to structure output for the
    #formatters.
    module Formatting
      #To create lists and sublist of data, you can use #list to wrap code
      #in a #begin_list / #end_list pair.
      def list(name, options={}) #:yield:
        begin_list(name, options)
        yield if block_given?
        end_list
      end

      #Tells the main collector to begin a list.  Subsequent output will be
      #gathered into that list.  For more, check out Results::Collector
      def begin_list(name, options={})
        $stdout.relevant_collector.begin_list(name, options)
      end

      #Tells the main collector to end the current list.  For more, check out
      #Results::Collector
      def end_list
        $stdout.relevant_collector.end_list
      end

      #Clean way to create an item of output.  Allows for various options to
      #be added.  The normal output method (#puts, #p, #write...) are all
      #diverted within a command, and effectively create no-option items.
      def item(name, options={})
        $stdout.relevant_collector.item(name, options)
      end

      #This returns a new Results::Collector, which can allow for some very
      #sophisticated command output.  Specifically, it can allow a command
      #to loop over a large amount of data once, depositing output in
      #multiple lists at once, for instance a status list (with hashmarks)
      #and results(with useful data) list.
      def sub_collector
        $stdout.relevant_collector.dup
      end
    end
  end
end
