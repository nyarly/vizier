require 'stencil/directives/text'
require 'vizier/arguments'
require 'vizier/task/base'

module Vizier
  module Task
    class Resume < Base
      optional.argument :deck, "Resume from name"
      subject_methods :chain_of_command, :pause_decks

      def undo; end

      def action
        chain_of_command.insert(0, *(pause_decks[deck]))
      end
    end

    class Quit < Base
      subject_methods :interpreter

      def undo; end

      def action
        interpreter.stop
      end
    end

    class Help < Base
      optional.multiword_argument(:terms) do |terms,last_word,subject|
        node = subject.command_set.find_command(terms)
        result = node.command_list.keys.grep(/^#{last_word}/)
        #result = subject.command_set.completion_list(terms.join(" "),
        #subject).list
        result
      end

      subject_methods :interpreter_behavior, :command_set

      def action
        width = (interpreter_behavior)[:screen_width]
        @commands = []
        @mode = "single"
        if(terms.nil? || terms.empty?)
          @mode = "list"
          @commands = command_set.command_list
          @commands.delete(nil)
          @commands = @commands.to_a.sort_by{|name,cmd| name}.map do |name,cmd|
            {
              :name => name,
              :command => cmd
            }
          end
        else
          command = command_set.find_command(terms)
          @commands = [{
            :name => terms.last,
            :command => command
          }]
        end
      end

      def subject_view
        {
          "width" => item{(interpreter_behavior)[:screen_width]},
          "indent" => 3,
          "mode" => item{@mode},
          "commands" => list{@commands}.map do
          {
            "name" => item{self[:name]},
            "arguments" => item{self[:command].arg_docs || ""},
            "documentation" => item{self[:command].doc_text || ""}
          }
          end
        }
      end

      def undo; end
    end

    class Undo < Base
      def undo; end
      def action
        command=undo_stack.get_undo
        command.undo
      end

      subject_methods :undo_stack

#      document <<-EOH
#        Undoes the most recently used command, if possible.
#      EOH
    end

    class Redo < Base
      def undo; end
      def action
        command=undo_stack.get_redo
        command.execute
      end

#      document <<-EOH
#        Redoes the most recently used command, if possible.
#      EOH
    end

    module Mode
      class Enter < Base
        subject_methods :interpreter
        def undo; end

        def action
          interpreter.push_mode(nesting[-1], execution_context)
        end
      end

      class Exit < Base
        subject_methods :interpreter
        def undo; end

        def action
          interpreter.pop_mode
        end
      end
    end

    module Set
      class Add < Base
        multiword_argument(:address) do |terms, term, subject|
          thumb = Vizier::Visitors::ArgumentAddresser.go(terms, [Vizier::Settable, Vizier::Repeating], subject.command_set)
          unacceptable if thumb.get_argument(term).nil? #This seems backwards
          thumb.completions(term)
        end

        proxy_argument :value do |proxy|
          proxy.address = "address"
          proxy.fixup = proc do |arg|
            arg.unwrap(Vizier::Settable).unwrap(Vizier::Repeating)
          end
        end

        subject_methods :knobs, :command_set

        def action
          @listing = nil

          @knob_name = address.pop
          @knobs = knobs
          address.each do |step|
            unless @knobs.has_key?(step)
              @knobs[step] = {}
            end
            @knobs = @knobs[step]
          end

          @original_value = @knobs[@knob_name].dup
          @knobs[@knob_name] << self.value
        end

        def undo
          @knobs[@knob_name] = @original_value
        end
      end

      class Clear < Base
        multiword_argument(:address) do |terms, term, subject|
          thumb = Vizier::Visitors::ArgumentAddresser.go(terms, [Vizier::Settable, Vizier::Repeating], subject.command_set)
          unacceptable if thumb.get_argument(term).nil?
          thumb.completions(term)
        end

        subject_methods :knobs, :command_set

        def action
          @listing = nil

          @knob_name = address.pop
          @knobs = knobs
          address.each do |step|
            unless @knobs.has_key?(step)
              @knobs[step] = {}
            end
            @knobs = @knobs[step]
          end

          @original_value = @knobs[@knob_name].dup
          @knobs[@knob_name] = []
        end

        def undo
          @knobs[@knob_name] = @original_value
        end
      end

      class Remove < Base
        multiword_argument(:address) do |terms, term, subject|
          thumb = Vizier::Visitors::ArgumentAddresser.go(terms, [Vizier::Settable, Vizier::Repeating], subject.command_set)
          unacceptable if thumb.get_argument(term).nil? #This seems backwards
          thumb.completions(term)
        end

        proxy_argument :value do |proxy|
          proxy.address = "address"
          proxy.fixup = proc do |arg|
            arg.unwrap(Vizier::Settable).unwrap(Vizier::Repeating)
          end
        end

        subject_methods :knobs, :command_set

        def action
          @listing = nil

          @knob_name = address.pop
          @knobs = knobs
          address.each do |step|
            unless @knobs.has_key?(step)
              @knobs[step] = {}
            end
            @knobs = @knobs[step]
          end

          @original_value = @knobs[@knob_name].dup
          @knobs[@knob_name].delete(self.value)
        end

        def undo
          @knobs[@knob_name] = @original_value
        end
      end

      class Reset < Base
        multiword_argument(:address) do |terms, term, subject|
          thumb = Vizier::Visitors::ArgumentAddresser.go(terms, [Vizier::Settable], subject.command_set)
          unacceptable if thumb.get_argument(term).nil? #This seems backwards
          thumb.completions(term)
        end

        subject_methods :knobs, :command_set

        def action
          @knob_name = address.pop
          @knobs = knobs
          address.each do |step|
            unless @knobs.has_key?(step)
              @knobs[step] = {}
            end
            @knobs = @knobs[step]
          end
          @original_value = @knobs[@knob_name]

          argument = ArgumentFinder.new(address, command_set).go.argument
          if argument.has_feature(Default)
            @knobs[@knob_name] = argument.default
          else
            @knobs[@knob_name] = nil
          end
        end

        def undo
          @knobs[@knob_name] = @original_value
        end

        def subject_view
          {
            :address => item{address + [@knob_name]},
            :old_value => item{@value},
            :new_value => item{@knobs[@knob_name]}
          }
        end
      end

      class Show < Base
        optional.multiword_argument(:address) do |terms, term, subject|
          thumb = Vizier::Visitors::ArgumentAddresser.go(terms, [Vizier::Settable], subject.command_set)
          thumb.completions(term)
        end

        def undo; end

        subject_methods :knobs, :command_set

        def action
          if address.nil?
            @address = []
            @value = knobs.to_a.sort
          else
            @address = address.dup
            @knob_name = address.pop
            @knobs = knobs
            address.each do |step|
              unless @knobs.has_key?(step)
                @knobs[step] = {}
              end
              @knobs = @knobs[step]
            end
            @value = @knobs[@knob_name]
            if Hash === @value
              @value = @value.to_a.sort
            end
          end
        end

        def subject_view
          {
            :address => item{@address.join(" ")},
            :listing => item{@value}
          }
        end
      end

      class Set < Base
        multiword_argument(:address) do |terms, term, subject|
          thumb = Vizier::Visitors::ArgumentAddresser.go(terms, [Vizier::Settable], subject.command_set)
          unacceptable if thumb.get_argument(term).nil? #This seems backwards
          thumb.completions(term)
        end

        proxy_argument :value do |proxy|
          proxy.address = "address"
          proxy.fixup = proc do |arg|
            arg.unwrap(Vizier::Settable)
          end
        end

        subject_methods :knobs, :command_set

        def action
          @listing = nil

          @knob_name = address.pop
          @knobs = knobs
          address.each do |step|
            unless @knobs.has_key?(step)
              @knobs[step] = {}
            end
            @knobs = @knobs[step]
          end

          @original_value = @knobs[@knob_name]
          @knobs[@knob_name] = self.value
        end

        def undo
          @knobs[@knob_name] = @original_value
        end

        def subject_view
          {
            :address => item{address.nil? ? nil : address + [@knob_name]},
            :listing => item{(@listing || []).to_a.sort_by{|k,v| k}}
          }
        end

#        template_for(:text, <<-EOT)
#          <<<
#          [;if not @:listing.empty? ;][;
#          with @:address;][;= @:address.join("/");]: [;/;]
#          [;each @:listing item;][;
#          = @#0;]: [;= @#1;]
#          [;/ 2;]
#        EOT

#        document <<-EOH
#          Sets <name> to <value>.  Most settings should be obvious.  But
#          some important ones probably won't be.
#        EOH
      end
    end
  end
end
