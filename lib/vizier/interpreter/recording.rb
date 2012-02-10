require 'vizier/interpreter/text'
require 'vizier/formatter/hash-array'
require 'yaml'
require 'enumerator'

module Vizier
  class RecordingInterpreter < TextInterpreter
    class Event
      def playback(prompt, interpreter, previous)
        raise NotImplementedError
      end
    end

    class Complete < Event
      def initialize(buffer, prefix, result)
        @buffer, @prefix, @result = buffer, prefix, result
      end

      attr_reader :buffer, :prefix, :result

      def eql?(other)
        return (self.buffer.eql?(other.buffer) and self.prefix.eql?(other.prefix))
      end

      def playback(prompt, interpreter, previous)
        complete_list = interpreter.readline_complete(@buffer, @prefix)
        if complete_list.nil?
          puts prompt + @buffer + "<TAB>"
          puts
        elsif complete_list.length > 1
          if previous.eql?(self)
            puts "<TAB>"
            complete_list.map{|item| item.ljust(15)}.each_slice(5) do|cons|
              puts cons.join
            end
          else
            print "\n" + prompt + @buffer + "<TAB>"
          end
        else
          puts "\n" + prompt + @buffer + "<TAB>"
          complete_list.map{|item| item.ljust(15)}.each_slice(5) do|cons|
            puts cons.join
          end
        end
      end
    end

    class Execute < Event
      def initialize(line)
        @line = line
        @result = nil
      end

      def playback(prompt, interpreter, previous)
        puts "\n" + prompt + @line
        interpreter.process_input(@line)
      end

      attr_writer :result
    end

    def initialize(file, mod)
      @events = []
      @current_hash_array = nil
      @set_path = File::expand_path(file)
      @module_name = mod
      super()
      self.command_set = Vizier::define_commands do
        require_commands(mod, file)
      end
    end

    def readline_complete(buffer, prefix)
      result = super
      @events << Complete.new(buffer, prefix, result)
      return result
    end

    def process_line(line)
      event = Execute.new(line)
      @events << event
      super
      event.result = @current_hasharray.structure
    end

    def get_formatters
      @current_hasharray = Results::HashArrayFormatter.new
      return [get_formatter, @current_hasharray]
    end

    def dump_to(io)
      setup = {
        'events' => @events,
        'set_path' => @set_path,
        'module_name' => @module_name
      }
      io.write(YAML::dump(setup))
    end
  end

  class PlaybackInterpreter < TextInterpreter
    def initialize(recording, pause_for)
      setup = nil
      File::open(recording) do |record|
        setup = YAML::load(record)
      end

      @events = setup['events']
      module_name = setup['module_name']
      command_set_path = setup['set_path']

      super()
      self.command_set = Vizier::define_commands do
        require_commands(module_name, command_set_path)
      end

      @pause_for = pause_for
    end

    def go
      ([nil] + @events).each_cons(2) do |last, event|
        sleep(@pause_for) unless @pause_for.nil?
        event.playback(get_prompt, self, last)
        $stdout.flush
      end
    end
  end
end
