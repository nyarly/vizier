require 'vizier'
require 'vizier/standard-commands'
require 'vizier/interpreter/quick'

class SpecFormatter < Vizier::Results::Formatter
  def initialize(results)
    super()
    @results = results
  end

  attr_reader :results

  def closed_item(item)
    @results << item.value
    ::Vizier::raw_stdout.puts item.value
  end
end

describe "A command set with the Set command", :type => :command_set do
  command_set do
    include_commands StdCmd::Set

    settable.number_argument :one, 1..10
    settable.number_argument :two, 1..10

    sub_command :sub do
      settable.number_argument :three, 1..10
      settable.number_argument :four, 1..10

      command :sub do
        settable.number_argument :five, 1..10
        settable.number_argument :six, 1..10
        settable.repeating.string_argument :words
      end
    end
  end

  subject({
    :knobs => {
      "one" => 1,
      "two" => 2,
      "sub" => {
        "three" => 3,
        "four" => 4,
        "sub" => {
          "five" => 5,
          "six" => 6,
          "words" => %w{these are some words}
  } }
    }
  })

  it "should actually have the set command" do
    command_set.command_list.should have_key("set")
  end

  it "should modify deep values" do
    process("set sub sub five 9")
    vizier_subject.knobs["sub"]["sub"]["five"].should eql(9)
  end

  it "should reply to empty arguments with first level keys" do
    process("show")

    view.should have_subview({
      "listing" => [
        ["one", 1],
        ["sub"],
        ["two", 2]
    ],
      "address" => ""
    })
  end

  it "should add to the end of list settings" do
    process "add sub sub words indeed"
    vizier_subject.knobs["sub"]["sub"]["words"].should include("indeed")
  end

  it "should remove items from list settings" do
    process "remove sub sub words some"
    vizier_subject.knobs["sub"]["sub"]["words"].should_not include("some")
    vizier_subject.knobs["sub"]["sub"]["words"].should include("are", "words")
  end

  it "should clear list settings" do
    process "clear sub sub words"
    vizier_subject.knobs["sub"]["sub"]["words"].should be_empty
  end


  it "should complete empty argument with option list" do
    complete("set ").list.should include("one", "sub", "two")
  end

  it "should reply to key with value" do
    pending "Set is changing radically soon"
    process("set one")
    view.should have_subview({
      "listing" => [["one", 1]]
    })
  end

  it "should reply to subkeys with key list" do
    process("show sub")
    view.should have_subview({
      "listing" => [
        ["four", 4],
        ["sub", {}],
        ["three", 3]
    ],
      "address" => "sub"
    })
  end

  it "should silently modify values" do
    process("set one 2")
    #results.should be_empty

    view.should have_subview({
      "listing" => []
    })
    vizier_subject.knobs["one"].should eql(2)
  end

end

describe "A command set with Set and Undo", :type => :command_set do
  command_set do
    include_commands StdCmd::Set
    include_commands StdCmd::Undo

    settable.number_argument :one, 1..10
    settable.number_argument :two, 1..10
  end

  subject(
    :knobs => { "one" => 1, "two" => 2 },
    :undo_stack => Vizier::UndoStack.new
  )

  it "should actually have the set and undo commands" do
    command_set.command_list.should have_key("set")
    command_set.mode_commands.should have_key("undo")
  end

  it "should return 'undo' in a complete" do
    complete("").list.should include("undo")
  end

  it "should report an error on impossible undo" do
    proc do
      process("undo")
    end.should raise_error(Vizier::CommandException)
  end

  it "should return to original value following undo" do
    process("set one 7")
    vizier_subject.knobs["one"].should eql(7)
    process("undo")
    vizier_subject.knobs["one"].should eql(1)
    proc do
      process("undo")
    end.should raise_error(Vizier::CommandException)
  end

end

#describe "A CommandSet with a submode" do
#  before do
#    @set.command_set = Vizier::CommandSet.define_commands do
#    end
#  end
#
#  it "should switch to submode and exit" do
#
#  end
#end

describe "A command set with Help", :type => :command_set do
  command_set do
    include_commands StdCmd::Help
    include_commands StdCmd::Undo

    command :long_winded do
      array_argument :pick, [1,2,3].map{|n| n.to_s}
      document <<-EOH
        This is an intentionally long help desciption used to test the
        String#wrap method.  I expect that even 'help long_winded' won't
        have a line longer than 78 characters.  And if it does I will be
        quite perturbed.
      EOH
    end

    command :silent do
    end

    sub_command :has_root do
      root_command do
      end
    end
  end

  subject({
    :interpreter_behavior => {
    :screen_width => 78
  }})


  it "should actually have the help command" do
    command_set.command_list.should have_key("help")
  end

  it "should complete with a list of commands with help available" do
    complete("help ").list.sort.should == %w{has_root help long_winded redo silent undo}
  end

  it "should not complete the arguments of commands" do
    complete("long_winded ").list.sort.should == %w{1 2 3}
    complete("help long_winded ").list.should be_empty
  end

  it "should process regardless of stray whitespace" do
    process("help long_winded ")

    view.should have_subview(
      {
      "mode" => "single",
      "commands" => [ {
      "name" => "long_winded"
    }] })
  end

  it "should return help text of included commands" do
    process "help undo"
    view.should have_subview(
      {
      "commands" => [ {
      "name" => "undo"
    }]
    }
    )
  end

  it "should return useful text in response to \"help\"" do
    process("help")

    view.should have_subview(
      {
      "mode" => "list",
      "commands" => [ {
      "name" => "has_root"
    }, {
      "name" => "help"
    }, {
      "name" => "long_winded",
      "arguments" => %w{<pick>},
      "documentation" => match(/^This is an/)},
      {
      "name" => "redo"
    },
      {
      "name" => "silent"
    },
      {
      "name" => "undo"
    }]}
    )
  end

  it "should return useful text in response to \"help help\"" do
    process("help help")
    view.should have_subview(
      {
      "mode" => "single",
      "commands" => [{
      "name" => "help",
      "arguments" => ["[terms]"],
      "documentation" => match(/hopefully/)
    }]
    }
    )
  end

  it "should gracefully recover if a command has nil documentation" do
    proc do
      process("help silent")
    end.should_not raise_error
  end
end

describe "StdCmd::Mode" do
  before do
    @interpreter = Vizier::QuickInterpreter.define_commands do
      sub_command :mode do
        include_commands StdCmd::Mode
        optional.string_argument :list_item, "Next list item"

        command :test do
          subject_methods :list

          parent_argument :list_item
          action do
            subject.list << (list_item || "a")
          end
        end
      end
    end

    @interpreter.fill_subject do|s|
      s.list = []
      s.interpreter = @interpreter
    end
  end

  it "should enter and leave a mode" do
    @interpreter.process_input("mode test")
    @interpreter.subject.list.length.should == 1
    @interpreter.process_input("mode")
    @interpreter.process_input("test")
    @interpreter.subject.list.length.should == 2
    @interpreter.process_input("exit")
    @interpreter.process_input("mode test")
    @interpreter.subject.list.should eql(["a", "a", "a"])
  end

  it "should retain the arguments to the mode" do
    @interpreter.process_input("mode thing")
    @interpreter.process_input("test")
    @interpreter.process_input("test")
    @interpreter.process_input("test")
    @interpreter.subject.list.should eql(["thing", "thing", "thing"])
  end
end

describe Vizier::StandardCommands, "resume" do
  before do
    @interpreter = Vizier::QuickInterpreter.define_commands do
      command :test do
        argument :added, "String"

        subject_methods :list
        action do
          subject.list << added
        end
      end

      include_commands StdCmd::Resume

      command :pause do
        action do
          task :wait_here do
            pause
          end
        end
      end

      command :two_step do
        argument :add_first, "String"
        argument :add_second, "String"

        action do
          chain "test", {:added => add_first()}
          chain "pause", {}
          chain "test", {:added => add_second()}
        end
      end
    end

    @interpreter.fill_subject {|s| s.list = []}
  end

  it "should pause and resume" do
    @interpreter.process_input("two_step one two")

    @interpreter.subject.list.should eql(["one"])
    @interpreter.process_input("resume")
    @interpreter.subject.list.should eql(["one", "two"])
  end
end
