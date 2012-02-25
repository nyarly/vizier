require "vizier/interpreter/text"
require 'vizier/command-description'
require 'vizier/engine'
describe Vizier::Engine do
  let :command_set do
    Vizier::describe_commands {}
  end

  let :engine do
    Vizier::Engine.new(command_set)
  end

  it "should set up and verify an actual subject" do
    subject = Vizier::Subject.new
    engine.prep_subject(subject)
    proc do
      engine.subject = subject
    end.should_not raise_error
  end
end

describe Vizier::TextInterpreter do
  let :engine do
    mock("Engine").as_null_object
  end

  let :command_set do
    mock("CommandSet").as_null_object
  end

  describe "splitting lines" do
    before do
      @interpreter = Vizier::TextInterpreter.new(command_set, engine)
    end

    it "should split line at spaces" do
      @interpreter.split_line('A test line').should eql(["A", "test", "line"])
    end

    it "should split around quoted strings" do
      @interpreter.split_line('A "test line"').should eql(["A", "test line"])
    end

    it "should not split escaped spaces" do
      @interpreter.split_line('A test\ line').should eql(["A", "test line"])
    end

    it "should ignore embedded quotes" do
      @interpreter.split_line("test's line").should eql(["test's", "line"])
    end

    it "should ignore escaped quotes" do
      @interpreter.split_line('A \"test\" line').should eql(["A", '"test"', "line"])
    end

    it "should ignore escaped quotes" do
      @interpreter.split_line('A \"test\" line').should eql(["A", '"test"', "line"])
    end

    it "should split multiple spaces only once" do
      @interpreter.split_line('A   test  line').should eql(["A", "test", "line"])
    end

    it "should ignore leading spaces" do
      @interpreter.split_line(' A test line').should eql(["A", "test", "line"])
    end

    it "should leave an empty word at the end of a line" do
      @interpreter.split_line('A ').should eql(["A", ""])
    end

    it "should leave an empty word at the end of a line after quoted words" do
      @interpreter.split_line('"A pear" ').should eql(["A pear", ""])
    end
  end


  #  it "should complete based on current mode" do
  #  end
  #  it "should execute root_commands"
  #  end

  describe "has a readline completion routine that" do
    before do
      @b = ""
      @s = ""
      @interpreter = Vizier::TextInterpreter.new(command_set, engine)
      @interpreter.command_set = Vizier::define_commands do
        command :test do
          array_argument :item, subject.list
          action {}
        end

        command :type do
          action {}
        end

        include_commands StdCmd::Quit
      end
    end

    it "should complete prefixes of space-embedding arguments" do
      @interpreter.fill_subject {|s| s.list = ["A b b", "A b c"]}
      @interpreter.readline_complete('', '').sort.should eql(["quit", "test", "type"])
      @interpreter.readline_complete('test ', '').sort.should eql(['"A b b"', '"A b c"'])
      #@interpreter.readline_complete("test \"", "").sort.should eql(['A b b"',
      #'A b c"'])
    end

    it "should complete prefixes of mixed completions" do
      @interpreter.fill_subject {|s| s.list = ["A list", "Another"]}
      ["\"#{@b}A#{@s} list\"", "\"#{@b}A#{@s}nother\""].should include(*@interpreter.readline_complete("test A", 'A'))
    end

    it "should return tricky error message instead of raising an exception" do
      @interpreter.fill_subject {|s| s.list = ["A b b", "A b c"]}
      proc do
        badcomplete = @interpreter.readline_complete(nil, nil)
        badcomplete.length.should == 2
        badcomplete[0].should =~ /^TypeError/
          badcomplete[1].should == ""
      end.should_not raise_error
    end

    it "should complete 'quit'" do
      @interpreter.readline_complete("q", "q").should eql(["quit"])
    end
  end
end

describe Vizier::TextInterpreter do
  before do
    @interpreter = Vizier::TextInterpreter.new

    @interpreter.instance_eval do
      @script = []
    end

    def @interpreter.set_readline_completion(&block)
      return block
    end

    def @interpreter.readline(prompt,something=false)
      if @script.nil? or @script.empty?
        stop
        return ""
      else
        line = @script.shift
      end

      if line == "INTERRUPT"
        raise Interrupt,"here"
      else
        return line
      end
    end

    def @interpreter.command(line)
      @script << line
    end

    def @interpreter.pause_before_dying(ex)
      @out_io.puts "Exception: #{ex.message}"
      @out_io.puts "Waiting for return"
      stop
    end

    def @interpreter.output_result(result)
    end

    @interpreter.template_files = Valise::Set.new()
  end

  describe "all set up" do
    before do
      @interpreter.command_set = Vizier::define_commands do
        sub_command :test1 do
          command :test2 do
            argument :thing, "thing"

            subject_methods :tested

            doesnt_undo

            action do
              subject.tested[0] = thing
            end
          end
        end

        command :try do

        end
      end

      @subject = @interpreter.subject_template
      @subject.tested = []
      @interpreter.subject = @subject
    end

    it "should complete words in the commmand-line" do
      @interpreter.complete_line=true
      @interpreter.cook_input("te te mc").parsed_tokens.should eql(["test1", "test2", "mc"])
    end

    it "should fail on missing commands on the commmand-line" do
      @interpreter.complete_line=true
      proc do
        @interpreter.cook_input("tk te mc")
      end.should raise_error(Vizier::CommandException)
    end

    it "should fail on ambiguous commands on the commmand-line" do
      @interpreter.complete_line=true
      proc do
        @interpreter.cook_input("t te mc")
      end.should raise_error(Vizier::CommandException)
    end

    it "should complete words from user" do
      @interpreter.readline_complete("test1 te", "te").should eql(["test2"])
    end

    it "should process a single command-line" do
      @interpreter.process_line("test1 test2 mctesty")
      @subject.get_image([:tested]).tested.should eql(["mctesty"])
    end

    it "should process commands from user" do
      @interpreter.command("test1 test2 mctesty")
      @interpreter.go
      @subject.get_image([:tested]).tested.should eql(["mctesty"])
    end

    it "should prompt the user and return their answer" do
      @interpreter.command("yes")
      @interpreter.prompt_user("Works?").should eql("yes")
    end
  end

  describe "receiving a command injection" do
    before do
      @interpreter.command_set = Vizier::define_commands do
        command :append do
          doesnt_undo
          subject_method :list

          number_argument :value

          action do
            subject.list << value
          end
        end

        command :onetwo do
          doesnt_undo
          action do
            chain :append, :value => "1"
            chain :append, :value => "2"
          end
        end
      end

      @subject = @interpreter.subject_template
      @subject.list = []
      @interpreter.subject = @subject
    end

    it "should execute injected commands after commands the user was typing" do
      def @interpreter.input_pending?
        true
      end

      @interpreter.inject_command(%w{append}, :value => "3")
      @interpreter.process_input("onetwo")
      @subject.list.should == [1,2,3]
    end
  end

  describe "with serious problems" do
    before do
      @interpreter.command_set = Vizier::define_commands do
        command :interrupt do
          doesnt_undo
          action do
            raise Interrupt, "thing"
          end
        end

        command :error do
          doesnt_undo
          action do
            raise Vizier::CommandException, "test"
          end
        end

        command :exception do
          doesnt_undo
          action do
            raise Exception, "test-exception"
          end
        end
      end

      @interpreter.subject = @interpreter.subject_template

      @catch_errors = StringIO.new
      @interpreter.out_io = @catch_errors
    end

    it "should ask the user to quit instead of Ctrl-C" do
      @interpreter.command("INTERRUPT")
      @interpreter.go
      @catch_errors.string.should == 'Interrupt: please use "quit"' + "\n"
    end

    it "should catch command errors and continue" do
      @interpreter.command("error")
      @interpreter.command("error")
      @interpreter.go

      @catch_errors.string.should == "Error: error: test\nError: error: test\n"
    end

    it "should catch exceptions and quit" do
      @interpreter.command("exception")
      @interpreter.command("exception")
      @interpreter.command("exception")
      @interpreter.go

      @catch_errors.string.should == "Exception: test-exception\nWaiting for return\n"
    end
  end

  describe "with a command with a named argument" do
    before do
      @interpreter.command_set = Vizier::define_commands do
        command :test do
          named.argument :something, 1..10

          subject_methods :tested

          doesnt_undo

          action do
            subject.tested[0] = something
          end
        end
      end
      @subject = @interpreter.subject_template
      @subject.tested = []
      @interpreter.subject = @subject
    end

    it "should complete words in the commmand-line" do
      @interpreter.complete_line=true
      @interpreter.cook_input("t s 4").parsed_tokens.should eql(["test", "something", "4"])
    end

    it "should process a command-line" do
      @interpreter.process_line("test something 4")
      @subject.get_image([:tested]).tested.should eql([4])
    end
  end

  describe "with a complex command set" do
    before do
      @interpreter.command_set = Vizier::define_commands do
        sub_command :sub do
          include_commands StdCmd::Mode
          array_argument :item, subject.list

          command :test do
            parent_argument :item

            doesnt_undo

            subject_methods :other_list
            action do
              subject.other_list << item
            end
          end
        end
      end

      @interpreter.fill_subject do |subject|
        subject.list = ["a","b","c"]
        subject.other_list = []
        subject.interpreter = @interpreter
      end
    end

    it "should process commands in mode that reference mode subject" do
      @interpreter.process_input("sub a")
      @interpreter.process_input("test")
      @interpreter.subject.get_image([:other_list]).other_list.should eql(["a"])
    end

    it "should issue an error message on bad commands" do
      proc do
        @interpreter.process_input("no such command")
      end.should raise_error(Vizier::CommandException)
    end
  end
end
