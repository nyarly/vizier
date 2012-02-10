require 'vizier/arguments'
require 'vizier'
require 'vizier/interpreter/quick'

module DSLBuilder
  def build_dsl
    @dsl = Object.new
    @dsl.extend Vizier::DSL::Argument
    class << @dsl
      def embed_argument(arg)
        @args||=[]
        @args << arg
      end
      def args
        @args
      end
    end
  end
end

describe Vizier::DSL::Argument do
  include DSLBuilder
  before do
    build_dsl
  end

  it "should create an ArrayArgument from an array" do
    @dsl.create(:test, [:a,:b,:c]).should be_an_instance_of(Vizier::ArrayArgument)
  end

  it "should create a StringArgument from a string" do
    @dsl.create(:test, "TEST").should be_an_instance_of(Vizier::StringArgument)
  end

  it "should create a ProcArgument from a proc" do
    @dsl.create("test", (proc {|a,b|})).should be_an_instance_of(Vizier::ProcArgument)
  end

  it "should create a NumberArgument from a range" do
    @dsl.create("test", 1..100).should be_an_instance_of(Vizier::NumberArgument)
  end

  class OddClass; end

  it "should raise a typeerror on an unhandled type" do
    proc do
      @dsl.create("test", OddClass.new)
    end.should raise_error(TypeError)
  end

  it "should raise ArgumentError with missing based_on" do
    proc do
      @dsl.create(:test)
    end.should raise_error(ArgumentError)
  end

  it "should decorate arguments as optional" do
    @dsl.optional.number_argument(:test, 0..1)
    arg = @dsl.args.first
    arg.should_not be_required
    arg.should be_a_kind_of(Vizier::Argument)
  end

  it "should document it's own commands" do
    docs = Vizier::DSL::Argument.document
    docs.should be_an_instance_of(String)
    docs.should_not be_empty
  end
end


describe "A NumberArgument" do
  before do
    @subject= mock("Subject")
    @argument = Vizier::NumberArgument.new(:test, 0..10)
  end

  it "should complete arguments in range" do
    @argument.complete([], "1", @subject).list.should eql(["1"])
    @argument.complete([], "2", @subject).list.should eql(["2"])
    @argument.complete([], "12", @subject).list.should eql([])
  end

  it "should validate zero" do
    @argument.validate("0", @subject).should be(true)
  end

  it "should validate numbers" do
    @argument.validate("1", @subject).should be(true)
  end

  it "should not validate numbers out of range" do
    @argument.validate("11", @subject).should be(false)
  end

  it "should not validate non-numeric input" do
    @argument.validate("hello!", @subject).should be(false)
  end
end

describe Vizier::RestOfLineArgument do
  before do
    @subject= mock("Subject")
    @argument = Vizier::RestOfLineArgument.new(:test, nil)
  end

  it "should consume the rest of the line" do
    line = %w{these are some words}
    @argument.consume(@subject, line)["test"].should eql("these are some words")
    line.should be_empty
  end
end

describe "A MultiArgument" do
  before do
    @argument = Vizier::MultiArgument.new(:test, proc do |list, term, subject|
      if(term == "test")
        ["test"]
      else
        []
      end
    end)

    @subject = mock("Subject")
  end

  it "Should consume what it can, and put the rest back" do
    args = %w{test test bark test}
    @argument.consume(@subject, args)["test"].should eql(["test", "test"])
    args.should eql(["bark", "test"])
  end
end

describe Vizier::AlternatingArgument do
  before do
    @set = Vizier::QuickInterpreter.define_commands do
      command :test do
        alternating_argument :thing do
          argument :named, ["all", "some"]
          argument :percent, 0..100
        end

        action {}
      end
    end

    @subject = mock("Subject")
  end

  it "should consume to array" do
    @set.cook_input("test all").arg_hash["named"].should eql("all")
  end

  it "should consume to number" do
    @set.cook_input("test 34").arg_hash["percent"].should eql("34")
  end

  it "should raise with invalid arguments" do
    proc do
      @set.cook_input("test none")
    end.should raise_error(Vizier::CommandException)
  end
end

describe Vizier::Argument, "with decorators: optional named many" do
  before do
    @set = Vizier::QuickInterpreter.define_commands do
      command :test do
        optional.alternating do
          named.many.file_argument :examples
          array_argument :which, ["failures"]
        end

        action {}
      end
    end
  end

  it "should parse named many array" do
    cmd = @set.cook_input("test examples #{__FILE__}")
    cmd.arg_hash["examples"].should eql([__FILE__])
  end

  it "should parse array" do
    parsed = @set.cook_input("test failures").arg_hash
    parsed["which"].should eql("failures")
  end

  it "should parse without arguments" do
    parsed = @set.cook_input("test").arg_hash
    parsed.should == {}
  end

end

describe Vizier::ArrayArgument, "with spaces in options", :type => :command_set do
  let :set do
    Vizier::QuickInterpreter.define_commands do
      command :test do
        array_argument :list, [
          "The quick brown fox",
          "The lazy dog",
          "jumped over"
        ]

        action {}
      end
    end
  end

  it "should complete properly with a common prefix" do
    set.complete_input('test "T').list.should == [
      "The quick brown fox",
      "The lazy dog"
    ]
  end

  it "should complete properly from a space" do
    set.complete_input('test "The ').list.should == [
      "The quick brown fox",
      "The lazy dog"
    ]
  end
end

describe Vizier::Argument, "with decorator: settable", :type => :command_set do
  let :set do
    Vizier::QuickInterpreter.define_commands do
      settable.number_argument :x, 1..10
      command :test do
        parent_argument :x
        settable.number_argument :y, 1..10

        doesnt_undo
        subject_methods :product

        action do |output|
          self.product = x * y
          output["product"] = x * y
        end
      end
    end.tap do |set|
      set.fill_subject do|subject|
        subject.product = nil
        subject.knobs = {
          "x" => 3,
          "test" => { "y" => 4 }
        }
      end
    end
  end

  it "should get values from settings" do
    set.process_input "test"
    set.subject.product.should == 12
  end
end

describe Vizier::Argument, "with decorators: many, alternating, named" do
  before do
    @set = Vizier::QuickInterpreter.define_commands do
      command :test do
        #      optional.many.alternating do
        #        array_argument :which, ["this", "that"]
        #        named.many.range_argument :numbers, 1..3
        #      end
        many.alternating do
          array_argument :which, ["this", "that"]
          named.many.range_argument :numbers, 1..3
          named.many.array_argument :when, ["now", "later"]
          end

        action {}
      end
    end
  end

  it "should parse one pick" do
    parsed = @set.cook_input("test this").arg_hash
    parsed["which"].should eql(["this"])
    parsed["numbers"].should == nil
    parsed["when"].should == nil
  end

  it "should parse many numbers" do
    parsed = @set.cook_input("test numbers 1 2 3").arg_hash
    parsed["numbers"].should eql(%w{1 2 3})
  end

  it "should parse many from array" do
    parsed = @set.cook_input("test when now now now").arg_hash
    parsed["when"].should eql(%w{now now now})
  end

  it "should parse numbers, pick and more numbers" do
    parsed = @set.cook_input("test numbers 3 2 2 1 that numbers 2 2").arg_hash
    parsed.keys.sort.should eql(%w{numbers which})
    parsed["which"].should eql(["that"])
    parsed["numbers"].should eql(%w{3 2 2 1 2 2})
  end

  it "should complete 'when now'" do
    completed = @set.complete_input("test when no").list
    completed.should eql(["now"])
  end

  it "should complete 'when now now'" do
    completed = @set.complete_input("test when now no").list
    completed.should eql(["now"])
  end

  it "should not complete 'now'" do
    @set.complete_input("test no").list.should be_empty
  end
end
