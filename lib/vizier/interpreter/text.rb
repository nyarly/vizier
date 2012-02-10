require 'vizier'
require 'vizier/interpreter/base'
require 'vizier/formatter/strategy'
require 'orichalcum/readline'

module Vizier
   class TextInterpreter < BaseInterpreter
     def initialize
       super
       @complete_line = false
       @behavior.merge!(
         :prompt => [/(?:: )?$/, "> "]
       )
       @templates = {}
       @template_files = nil
     end

     attr_accessor :complete_line, :template_files

     def go
       raise "command_set unset!" if @command_set.nil?
       raise "subject unset!" if @subject.nil?
       raise "template_files is unset!" if @template_files.nil?

       @stop = false

       begin
         old_proc = set_readline_completion do |prefix|
           readline_complete(Readline.line_buffer, prefix)
         end

         line = readline(get_prompt, true)
         if line.nil?
           puts
           break
         end
         next if line.empty?
         process_line(line)
       rescue Interrupt
         @out_io.puts "Interrupt: please use \"quit\""
       rescue CommandException => ce
         output_exception("Error", ce)
       rescue ::Exception => e
         self.pause_before_dying(e)
       ensure
         unless old_proc.nil?
           set_readline_completion(&old_proc)
         end
       end until @stop
     end

     def output_exception(label, ex)
       @out_io.puts label + ": " + ex.message
       @out_io.puts ex.backtrace.join("\n") if @behavior[:debug_commands]
       logger.warn ex.message
       ex.backtrace.each do |line|
         logger.debug line
       end
     end

     def pause_before_dying(exception)
       output_exception("Exception", exception)
       puts "Waiting for return"
       $stdin.gets
       stop
     end

     def cook_input(line)
       if @complete_line
         command_visit(Visitors::ShortHandParser, VisitStates::CommandSetup, line)
       else
         command_visit(Visitors::InputParser, VisitStates::CommandSetup, line)
       end
     end

     alias single_command process_input
     alias process_line process_input

     def complete(line)
       list = current_command_set.completion_list(line, build_subject)

       if list.length == 0
         raise CommandException, "Unrecognized term: #{word}"
       end

       return word if list[-1].empty?

       if list.length == 1
         return list[0]
       else
         raise CommandException, "Ambiguous term: #{word}"
       end
     end

     def readline_complete(buffer, rl_prefix)
       begin
#         parsed_input = split_line(buffer)
#         prefix = parsed_input.pop
#
#         #Lest this kill coverage: hide exists to fix readline's irritating
#         #word splitting
#         hide = prefix.sub(%r{#{rl_prefix}$}, "")
#
#         if /"#{prefix}$/ =~ buffer
#           hide = '"' + hide
#         end
#
         hide=""
         completes = command_visit(Visitors::Completer, VisitStates::CommandArguments. buffer) do |completer|
           completer.resolve
           completer.completions
         end

         readline_list =
           case completes
           when Orichalcum::CompletionResponse
             completes.readline_list(rl_prefix) {|complete| split_line(complete).length > 1}
           else
             raise "Bad type: #{completes.class}: #{completes}"
           end
         return readline_list
       rescue Object => ex
         #It's really irritating for an app to crap out in completion
         #::Vizier::raw_stderr.puts(([ex.class, ex.message] +
         #ex.backtrace).inspect)
         return ["#{ex.class}: #{ex.message} at #{ex.backtrace[0]}",""]
       end
     end

     def split_line(line) #Input parsing - interpreter vs. argument concern
       line_array = [""]
       scanner = StringScanner.new(line)
       scanner.scan(/\s*/)

       until scanner.eos?
         next_break = scanner.scan(/['"]/) || '\s'
         line_array.last << scanner.scan(/[^#{next_break}\\]*/)
         stopped_by = scanner.scan(/[#{next_break}\\]/)
         if stopped_by == '\\'
           line_array.last << scanner.getch
         elsif not (stopped_by.nil? or stopped_by =~ /['"]/)
           scanner.scan(/\s*/)
           line_array << ""
         end
       end

       return line_array
     end

     def register_formatters(presenter)
       progress = Results::TextProgressFormatter.new(::Vizier::raw_stdout)
       presenter.register_formatter(progress)
     end

     def get_prompt
       prompt = ""

       prompt.sub!(*(@command_set.prompt))
       @sub_modes.each do |mode|
         prompt.sub!(*(mode[0].prompt))
       end
       prompt.sub!(*(@behavior[:prompt]))
     end

     def stop
       @stop = true
     end

     def prompt_user(message)
       readline(message)
     end


     def self.template_dir
       "text"
     end

     protected
     def set_readline_completion(&block)
       old_proc = Readline.completion_proc
       Readline.completion_proc = proc &block
       return old_proc
     end

     def readline(prompt, something=false)
       return Readline.readline(prompt, something)
     end
   end
end
