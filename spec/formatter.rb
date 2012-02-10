require 'vizier/results'
require 'vizier/formatter/strategy'
require 'vizier/command'

class MySpecFormatter < Vizier::Results::Formatter
  def initialize(io)
    @output = []
    super()
  end

  attr_reader :output

  def closed_begin_list(list)
    @output << list
  end

  def closed_item(item)
    @output << item
  end
end

describe Vizier::Results::Formatter do
  before do
    command = Vizier::Command.setup("test") do
      format_advice do
        list do |list|
          if list.options[:type] == :status
            {:type => :nested}
          end
        end

        item do |item|
          if item.depth >= 2
            {:display => :none}
          end
        end
      end

      doesnt_undo

      action do
        list("test_list", {:type => :status}) do
          item "1"
          item("Two", :compact => "2")
          puts "Whoa!"
          list("2") do
            item "missing"
          end
        end
      end
    end

    @formatter = MySpecFormatter.new(::Vizier::raw_stdout)
    subject = mock("Subject").as_null_object
    cmd = command.new(subject)

    cmd.advise_formatter(@formatter)
    box = Vizier::Results::Presenter.new
    box.register_formatter(@formatter)
    @collector =box.create_collector
    $stdout.add_dispatcher(@collector)
    cmd.consume_hash({})
    cmd.go(@collector)
  end

  after do
    $stdout.remove_dispatcher(@collector)
  end

  it "should process into the correct list" do
    @formatter.output.map{|i| i.to_s}.should eql(
      ["test_list", "1", "Two", "Whoa!", "2", "missing"])
  end

  it "should allow explicit options to come through from command" do
    @formatter.output[2].options[:compact].should eql("2")
  end

  it "should allow explicit list options through" do
    @formatter.output[0].options[:type].should eql(:status)
  end

  it "should mark up items as directed by Command#format_advice" do
    @formatter.output[0].options[:format_advice][:type].should eql(:nested)
  end

  it "should mark up items as directed by Command#format_advice" do
    @formatter.output[5].options[:format_advice][:display].should eql(:none)
  end
end

class SpecStrategyFormatter < Vizier::Results::StrategyFormatter
end

describe Vizier::Results::StrategyFormatter do
  before do
    command = Vizier::Command.setup(nil, "test") do
      format_advice do
        list do |list|
          if list.options[:type] == :status
            {:type => :nested}
          end
        end

        item do |item|
          if item.depth >= 2
            {:display => :none}
          end
        end
      end

      doesnt_undo

      action do
        list("test_list", {:type => :status}) do
          item "1"
          item("Two", :compact => "2")
          puts "Whoa!"
          list("2") do
            item "missing"
          end
        end
      end
    end

    @formatter = SpecStrategyFormatter.new(::Vizier::raw_stdout)
    cmd = command.new(Vizier::Subject.new)

    cmd.advise_formatter(@formatter)
    box = Vizier::Results::Presenter.new
    box.register_formatter(@formatter)
    @collector = box.create_collector
    $stdout.add_dispatcher(@collector)
    cmd.consume_hash({})
    cmd.go(@collector)
  end

  after do
    $stdout.remove_dispatcher(@collector)
  end

end

require 'vizier/formatter/hash-array'
describe Vizier::Results::HashArrayFormatter do
  before do
    @formatter = Vizier::Results::HashArrayFormatter.new
    presenter = Vizier::Results::Presenter.new
    presenter.register_formatter(@formatter)
    @collector = presenter.create_collector
  end

  it "should assemble a set of items" do
    @collector.item(1)
    @collector.item(2)
    @collector.item(3)
    @formatter.structure[:array].should eql([1,2,3])
  end

  it "should pack a list into a hash with an array" do
    @collector.begin_list("List")
    @collector.item(5)
    @collector.item(6)
    @collector.end_list()
    @formatter.structure["List"][:array].should eql([5,6])
  end

  it "should usefully structure mixed lists and items" do
    @collector.item(1)
    @collector.begin_list("A")
    @collector.item(2)
    @collector.item(3)
    @collector.end_list()
    @collector.item(4)
    @formatter.structure[:array].should eql([1,[2,3],4])
    @formatter.structure["A"]["2"].should eql(3)
  end

  it "should nest arrays for nested lists" do
    @collector.item(0)
    @collector.begin_list("A")
    @collector.item(1)
    @collector.begin_list("B")
    @collector.item(2)
    @collector.begin_list("C")
    @collector.item(3)
    @collector.item(4)
    @collector.item(5)
    @collector.end_list()
    @collector.end_list()
    @collector.end_list()
    @formatter.structure[:array].should eql([0,[1, [2, [3,4,5]]]])
  end
end
