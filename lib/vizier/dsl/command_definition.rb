module Vizier
  module DSL
    #These are the methods made available by Vizier::setup
    module CommandDefinition
      include Argument

      #See Vizier::Subject.  If this command will make use of fields of the
      #subject, it must declare them using subject_methods.  You're then
      #guaranteed that the subject will either have those fields defined, or
      #an error will be thrown at runtime.  Pass a list of symbols, as you
      #would to Class#attribute
      def subject_methods(*methods)
        @subject_requirements += [*methods]
      end
      alias subject_method subject_methods

      #Creates a parent argument reference: an argument that references an
      #argument from a subcommand.  This lets a subcommand collect the
      #arguments common to its commands and do two things: make command line
      #calls more natural (+box+ +grape_box+ +add+ +grapes+ instead of +box+
      #+add+ +grape_box+ +grapes+) and also make modes more useful, since
      #they can collect the arguments that would otherwise be repeated when
      #the mode is started.
      def parent_argument(name)
        name = name.to_s
        @parent_arguments << name.to_s
      end

      def parent_arguments(*names)
        names.each do |name|
          parent_argument(name)
        end
      end

      #The core of the Command.  Define a block that performs the command.
      #Within it, you can treat your arguments as readable private attributes
      #and call methods from DSL::Action
      def action(&block)
        define_method(:execute, &block)
      end

      #Commands should either define an undo block (that will reverse
      #whatever their action did) or else call doesnt_undo - for things that
      #don't change any state.
      #
      #One particularly useful feature is that each invocation is it's own
      #object, so you can set instance variables to save the old state if
      #you want.
      def undo(&block)
        define_method(:undo, &block)
        define_method(:undoable?) do
          return true
        end
        subject_requirements << :undo_stack
      end

      #Lets the interpreter know that this command intentionally doesn't
      #provide an undo block - that there's nothing to undo.  Use it for
      #informational commands, primarily.  Commands that neither declare
      #that they 'doesnt_undo' nor provide an undo block will raise a
      #warning to the user whenever they're called.
      def doesnt_undo
        define_method(:undoable?) { return true }
        define_method(:join_undo) {}
      end

      #Used to explain to the formatter subsystem how best to format your
      #output.  It can sometimes be useful to output lots of data, and then
      #use format_advice to eliminate and shuffle it around.
      #
      #For more information see Vizier::Formatter::FormatAdvisor
      def format_advice(&block)
        @advice_block = proc &block
      end

      #Every command should provide a little text to describe what it does.
      #This will be nicely formatted on output, so feel free to use heredocs
      #and indent so that it looks nice in the code.
      def document(text)
        @doc_text = text.gsub(%r{\s+}m, " ").strip
      end

      #This method is set for deprecation
      def template_for(kind, text)
        @template_files[kind.to_s] = text
      end

      #This method is set for deprecation
      def view(&block)
        view_set = Stencil::ViewHost::view(DSL::CommandView, &block)
        define_method(:view) do
          return view_set.viewset(self)
        end
      end

      def emit(&block)
        define_method(:view, &block)
      end

      #This method is set for deprecation
      def template(string)
        @template_string = string
        @template = nil
      end
    end
  end
end
