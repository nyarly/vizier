require "vizier/results"
require 'vizier/formatter/xml'

module ListUtil
  class ListMatch
    def initialize(name, lineno)
      @name = name
      @line_number = lineno
    end

    def matches?(value)
      return false unless Vizier::Results::List === value
      return value.name == @name
    end

    def description
      "Matches List <#@name> (from: #@line_number)"
    end
  end

  class ItemMatch
    def initialize(name, lineno)
      @name = name
      @line_number = lineno
    end

    def matches?(value)
      return false unless Vizier::Results::ListItem === value
      return value.value == @name
    end

    def description
      "Matches Item <#@name> (from: #@line_number)"
    end
  end

  def list(name, *list)
    Vizier::Results::List.new(name, list)
  end

  def item(value)
    Vizier::Results::ListItem.new(value)
  end

  def is_list(name)
    line = caller(0)[3]
    return ListMatch.new(name,line)
  end

  def is_item(name)
    line = caller(0)[3]
    return ItemMatch.new(name,line)
  end
end

describe Vizier::OutputStandin, "undispatched" do
  before do
    @real_io = StringIO.new
    @io = Vizier::OutputStandin.new(@real_io)
  end

  it "should return the base IO from getobj" do
    @io.__getobj__.should equal(@real_io)
  end

  it "should pass puts unmolested" do
    @io.puts "testing"

    @real_io.string.should eql("testing\n")
  end
end

share_examples_for "A dispatched OutputStandin" do
  it "should return the base IO from getobj" do
    @io.__getobj__.should equal(@real_io)
  end

  it "should send #puts to the collector" do
    @presenter.should_receive(:item)
    @io.puts "testing"
    @real_io.string.should eql("")
  end

  it "should send #p to the collector" do
    @presenter.should_receive(:item)
    @io.p "testing"
    @real_io.string.should eql("")
  end
end

describe Vizier::OutputStandin do
  before do
    @presenter = mock("Presenter")

    @real_io = StringIO.new
    @io = Vizier::OutputStandin.new(@real_io)
    root = Vizier::Results::List.new("")
    @collector = Vizier::Results::Collector.new(@presenter, root)
  end

  describe "dispatched to a collector" do
    it_should_behave_like "A dispatched OutputStandin"

    before do
      @io.add_dispatcher(@collector)
    end

    it "should go back to sending puts to IO if collector removed" do
      @io.remove_dispatcher(@collector)
      @io.puts "testing"

      @real_io.string.should eql("testing\n")
    end
  end

  describe "dispatched via thread" do
    it_should_behave_like "A dispatched OutputStandin"

    before do
      @io.add_thread_local_dispatcher(@collector)
    end

    it "should go back to sending puts to IO if collector removed" do
      @io.remove_thread_local_dispatcher(@collector)
      @io.puts "testing"

      @real_io.string.should eql("testing\n")
    end
  end
end

describe Vizier::Results::Collector, "sending messages" do
  before do
    @presenter = mock("Presenter")
    root = Vizier::Results::List.new("")
    @collector = Vizier::Results::Collector.new(@presenter, root)
  end

  it "should send simple #item calls to its presenter" do
    @presenter.should_receive(:item).with(anything(), "testing", {:test => "test"})
    @collector.item("testing", {:test => "test"})
  end

  it "should send begin_list and end list calls to presenter" do
    @presenter.should_receive(:begin_list).with(anything(), "name", {:option => 1})
    @presenter.should_receive(:end_list)
    @collector.begin_list("name", {:option => 1})
    @collector.end_list
  end

  it "should prefix items with list nesting" do
    @presenter.should_receive(:begin_list).with(anything(), "1", {}).once
    @presenter.should_receive(:begin_list).with(anything(), "2", {}).once
    @presenter.should_receive(:item).with(anything(), "testing", {})
    @presenter.should_receive(:end_list).twice
    @collector.begin_list("1")
    @collector.begin_list("2")
    @collector.item("testing")
    @collector.end_list
    @collector.end_list
  end
end

describe "A pair of", Vizier::Results::Collector do
  before do
    @presenter = Vizier::Results::Presenter.new
    @formatter = Vizier::Results::HashArrayFormatter.new
    @presenter.register_formatter(@formatter)
    @one = @presenter.create_collector
    @two = @presenter.create_collector
  end

  def check_results
    output = @formatter.structure
    output[:array].should eql([1,[1,1],2,[2,2]])
  end

  it "should collect results when used in sequence" do
    @one.item(1)
    @one.begin_list("list")
    @one.item(1)
    @one.item(1)
    @one.end_list

    @two.item(2)
    @two.begin_list("list")
    @two.item(2)
    @two.item(2)
    @two.end_list

    check_results
  end

  it "should collect results when calls are scrambled" do
    @one.item(1)
    @one.begin_list("list")
    @two.item(2)
    @two.begin_list("list")
    @one.item(1)
    @one.item(1)
    @one.end_list

    @two.item(2)
    @two.item(2)
    @two.end_list

    check_results
  end

  it "should collect results when calls appear nested" do
    @one.item(1)
    @one.begin_list("list")

    @two.item(2)
    @two.begin_list("list")

    @two.item(2)
    @one.item(1)

    @two.item(2)
    @two.end_list

    @one.item(1)
    @one.end_list

    check_results
  end

  it "should collect results when one gets delayed" do
    @one.item(1)
    @one.begin_list("list")

    @two.item(2)
    @two.begin_list("list")
    @two.item(2)
    @two.item(2)
    @two.end_list

    @one.item(1)
    @one.item(1)
    @one.end_list

    check_results
  end
end

describe Vizier::Results::Presenter do
  include ListUtil

  before do
    @presenter = Vizier::Results::Presenter.new
    @collector = @presenter.create_collector
  end

  it "should collect items" do
    @collector.item("1")
    @collector.item("2")
    @presenter.output.should eql(list("", "1", "2").close)
  end

  it "should nest lists" do
    @collector.begin_list("A")
    @collector.begin_list("B")
    @collector.item("1")
    @collector.end_list()
    @collector.end_list()
    @presenter.output.should eql(list("", list("A", list("B", "1"))).close)
  end
end

describe Vizier::Results::Presenter, "driving a Formatter" do
  include ListUtil

  before do
    presenter = Vizier::Results::Presenter.new
    @formatter = mock("Formatter").as_null_object
    presenter.register_formatter(@formatter)
    @collector = presenter.create_collector
  end

  it "should emit #saw_item and #closed_item" do
    @formatter.should_receive(:notify).with(:saw, item("x"))
    @formatter.should_receive(:notify).with(:arrive, item("x"))
    @collector.item("x")
  end

  it "should emit #closed_item within known tree order" do
    @formatter.should_receive(:notify).with(:arrive,item("1"))
    @collector.begin_list "a"
    @collector.begin_list "b"
    @collector.item "1"
  end

  it "should emit #closed_item only once per item" do
    require 'timeout'
    Timeout::timeout(1) do
      @formatter.should_receive(:notify).with(:arrive,anything()).exactly(3).times
      @collector.item 1
      @collector.item 1
      @collector.item 3
    end
  end
end

describe Vizier::Results::Presenter, "driving a strict Formatter" do
  include ListUtil

  before do
    @presenter = Vizier::Results::Presenter.new
    @formatter = Vizier::Results::TextFormatter.new(StringIO.new)
  end

  it "should send notifications in correct order" do
    @formatter.should_receive(:saw_begin_list).with(is_list("A"))
    @formatter.should_receive(:saw_begin_list).with(is_list("B"))
    @formatter.should_receive(:saw_item).with(is_item("1"))
    @formatter.should_receive(:saw_end_list).with(is_list("A"))
    @formatter.should_receive(:start).ordered
    @formatter.should_receive(:closed_begin_list).with(is_list("A")).ordered
    @formatter.should_receive(:closed_end_list).with(is_list("A")).ordered #OOO
    @formatter.should_receive(:closed_begin_list).with(is_list("B")).ordered
    @formatter.should_receive(:closed_item).with(is_item("1")).ordered
    @formatter.should_receive(:closed_end_list).with(is_list("B")).ordered
    @formatter.should_receive(:finish).ordered
    @presenter.register_formatter(@formatter)
    root = @presenter.output
    list_a = @presenter.begin_list(root, "A")
    list_b = @presenter.begin_list(root, "B")
    @presenter.item(list_b, "1")
    @presenter.end_list(list_a)
    @presenter.done
  end
end

module FormatDrive
  def drive_two_lists(f)
    #[[:a, :b, :c],[1,2,3]]

    f.start

    list_a = Vizier::Results::List.new("A")
    list_b = Vizier::Results::List.new("B")
    list_c = Vizier::Results::List.new("C")
    it_a = Vizier::Results::ListItem.new("a")
    it_b = Vizier::Results::ListItem.new("b")
    it_c = Vizier::Results::ListItem.new("c")
    it_1 = Vizier::Results::ListItem.new(1)
    it_2 = Vizier::Results::ListItem.new(2)
    it_3 = Vizier::Results::ListItem.new(3)

    it_x = Vizier::Results::ListItem.new("x")
    it_y = Vizier::Results::ListItem.new("y")
    it_z = Vizier::Results::ListItem.new("z")

    list_a.depth = 0
    list_b.depth = 0
    list_c.depth = 1

    it_inv = Vizier::Results::ListItem.new("inv")
    it_inv.options = {:format_advice => {:type => :invisible}}
    list_c.options = {:format_advice => {:type => :invisible}}


    f.saw_begin_list(list_a)
    f.saw_begin_list(list_b)
    f.saw_begin_list(list_c)
    f.saw_item(it_inv)
    f.saw_item(it_a)
     f.saw_item(it_1)
    f.saw_item(it_b)
      f.saw_item(it_x)
      f.saw_item(it_y)
      f.saw_item(it_z)
     f.saw_item(it_2)
     f.saw_item(it_3)
    f.saw_end_list(list_b)
    f.saw_end_list(list_c)
    f.saw_item(it_c)
    f.saw_end_list(list_a)

    #This separation isn't realistic - it *shouldn't* cause problems
    #And it's much easier to understand
    #It would be a problem for testing a formatter that inspects the
    #structure following a "saw_item"

    f.closed_begin_list(list_a)
     f.closed_item(it_inv)
     f.closed_item(it_a)
     f.closed_item(it_b)
     f.closed_begin_list(list_c)
      f.closed_item(it_x)
      f.closed_item(it_y)
      f.closed_item(it_z)
     f.closed_end_list(list_c)
     f.closed_item(it_c)
    f.closed_end_list(list_a)

    f.closed_begin_list(list_b)
     f.closed_item(it_1)
     f.closed_item(it_2)
     f.closed_item(it_3)
    f.closed_end_list(list_b)

    f.finish
  end
end

describe "A driven formatter" do
  include FormatDrive
  before do
    @out = StringIO.new
    @err = StringIO.new
  end

  describe Vizier::Results::XMLFormatter do
    before :each do
      @formatter = described_class.new(@out, @err)
    end

    it "should format two lists" do
      drive_two_lists(@formatter)
      @out.string.should eql("<A>\n  <item value=\"inv\" format_advice=\"type: invisible\" />\n  <item value=\"a\" />\n  <item value=\"b\" />\n  <C format_advice=\"type: invisible\">\n    <item value=\"x\" />\n    <item value=\"y\" />\n    <item value=\"z\" />\n  </C>\n  <item value=\"c\" />\n</A>\n<B>\n  <item value=\"1\" />\n  <item value=\"2\" />\n  <item value=\"3\" />\n</B>\n")
    end
  end

  describe Vizier::Results::StrategyFormatter do
    before :each do
      @formatter = described_class.new(@out, @err)
    end

    describe "with indent strategy" do
      before do
        @formatter.push_strategy(:indent)
      end

      it "should format two lists" do
        drive_two_lists(@formatter)
        @out.string.should eql("A\n  a\n  b\n  c\nB\n  1\n  2\n  3\n")
      end
    end

    describe "with chatty strategy" do
      before do
        @formatter.push_strategy(:chatty)
      end

      it "should format two lists" do
        drive_two_lists(@formatter)
        @out.string.should eql("> A (depth=0 {})\n  inv {:format_advice=>{:type=>:invisible}}\n  a\n  b\n> C (depth=1 {:format_advice=>{:type=>:invisible}})\n  x\n  y\n  z\n< C\n  c\n< A\n> B (depth=0 {})\n  1\n  2\n  3\n< B\n")
        @err.string.should eql("BBB.........EE.E")
      end
    end

    describe "with progress strategy" do
      before do
        @formatter.push_strategy(:progress)
      end

      it "should format two lists" do
        drive_two_lists(@formatter)
        @out.string.should eql("A...\nC...\n.\nB...\n")
      end
    end
  end
end
