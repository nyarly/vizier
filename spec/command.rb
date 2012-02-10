require 'vizier.rb'
require "vizier/interpreter/quick"

module Dummy
  module Cmds
    def self.define_commands
      return Vizier.describe_commands do
        command(:test) do

        end
      end
    end
  end

  module NoCmds
    def self.define_commands
      nil
    end
  end
end


describe "Command::require_commands" do
  it "should absorb commands from a module" do
    @set = Vizier::describe_commands do
      compose(Dummy::Cmds.define_commands)
    end
    @set.command_list.keys.should == [nil, "test"]
  end

  it "should absorb a single command from a module", :pending => "readdition" do
    @set = Vizier::require_commands("Dummy::Cmds", nil, ["test"])
    @set.command_list.keys.should == [nil, "test"]
  end


  it "should fail when module doesn't define commands", :pending => "consideration" do
    proc do
      @set = Vizier::require_commands(Dummy::NoCmds)
    end.should raise_error(RuntimeError)
  end
end

describe "A set of commands without a root command" do
  before do
    @set = Vizier.define_commands do
      command :test1 do
        subject_methods :prop_one
      end

      command :sub_one do
        command :test_two do
          subject_methods :prop_two, :prop_three
        end
      end
    end
  end

  it "should fail on missing commands" do
    proc do
      @set.find_command(%w{dont_exist})
    end.should raise_error(Vizier::CommandException)
  end
end

describe "An established command set" do
  before do
    @set = Vizier.define_commands do
      command :test1 do
        subject_methods :prop_one
      end

      command :sub_one do
        argument :thing, "hoowaw"
        subject_methods :prop_two

        command :test_two do
          subject_methods :prop_two, :prop_three
        end
      end
    end
    @subject = @set.add_requirements(Vizier::Subject.new)
  end

  it "should add all properties to subject" do
    @subject.should respond_to(:prop_one=)
    @subject.should respond_to(:prop_two=)
    @subject.should respond_to(:prop_three=)
  end

  it "should return Command class on configured classes" do
    command = @set.find_command(%w{test1})
    command.ancestors.should include(Vizier::Command)
  end

  it "should find the root command with an argument" do
    result = @set.process_terms("sub_one wobbly", @subject)
    result.arg_hash["thing"].should eql("wobbly")
    result.node.class.should == Vizier::Command
  end

  it "should return subcommands" do
    command = @set.find_command(%w{sub_one test_two})
    command.ancestors.should include(Vizier::Command)
    command.name.should eql("test_two")
  end

  it "should accept new commands in a subcommand" do
    @set.command :sub_one do
      command(:test_three){}
    end
    command = @set.find_command %w{sub_one test_two}
    command.ancestors.should include(Vizier::Command)
  end

  it "should add Command objects" do
    new_command = Vizier::Command.setup("dummy") {}
    @set.command(new_command)
    command = @set.find_command %w{dummy}
    command.name.should eql("dummy")
  end
end

#XXX is parent_argument necessary?
describe Vizier::Command, "with nested arguments", :pending => "replacement for parent_argument" do
  before do
    @cli = Vizier::QuickInterpreter.define_commands do
      command :try do
        include_commands StdCmd::Mode
        optional.alternating_argument :top do
          string_argument :test, "Test"
        end

        command :do_this do
          argument :bottom, "Time"
          parent_argument :top

          subject_methods :result

          action do |output|
            self.result << [top, bottom]
          end
        end
      end
    end

    @cli.fill_subject do |sub|
      sub.result = []
      sub.interpreter = @cli
    end
  end

  it "should honor all arguments" do
    @cli.process_input("try to do_this now")
    @cli.subject.result.should eql([["to", "now"]])
  end

  it "should prefer to parse commands over optional parent arguments" do
    @cli.process_input("try do_this now")
    @cli.subject.result.should eql([[nil, "now"]])
  end
end

describe Vizier::Command, "with cascading alternating subject-based arguments", :pending => "replacement for parent_argument" do

  before do
    @cli = Vizier::QuickInterpreter::define_commands do
      command :test do
        include_commands StdCmd::Mode

        alternating_argument :failure do
          array_argument :failure_name, subject.failures

          range_argument :failure_number, (subject.failures do |fs|
            1..fs.length
          end)
        end

        command :set_which do
          parent_argument :failure

          subject_methods :failures, :which

          action do |output|
            the_failure = if not failure_number.nil?
                            subject.failures[failure_number-1]
                          else
                            failure
                          end
            subject.which.replace([the_failure])
          end
        end
      end
    end

    @cli.fill_subject do |s|
      s.failures = ["one", "two", "three"]
      s.which = []
      s.interpreter = @cli
    end
  end

  it "should complete properly" do
    @cli.complete_input("test o").list.should eql(["one"])
  end

  it "should stash string for mode command retrieval" do
    @cli.process_input("test one")
    @cli.process_input("set_which")
    @cli.subject.which.should eql(["one"])
  end

  it "should stash number for mode command retrieval" do
    @cli.process_input("test 2")
    @cli.process_input("set_which")
    @cli.subject.which.should eql(["two"])
  end
end

describe Vizier::Command, "with subject defaults" do
  before do
    @set = Vizier::define_commands do
      command :increment_x do
        subject_methods :x, :results

        action do |output|
          self.results << x + 1
        end
      end

      subject_defaults( :x => 3)
    end

    @sub_set = Vizier::define_commands do
      command :add_y_to_x do
        subject_methods :x, :y, :results

        action do |output|
          self.results << self.x + self.y
        end
      end

      subject_defaults(:x => 100, :y => 200, :results => [])
    end
  end

  it "should set defaults on its subject" do
    @set.get_subject.get_image([:x]).x.should eql(3)
  end

  it "should be useable with an interpreter without update" do
    interpreter = Vizier::QuickInterpreter.new
    @set.include_commands(@sub_set)
    interpreter.command_set = @set
    #proc do
    interpreter.process_input("add_y_to_x")
    #end.should_not raise_error
  end

  it "should override the defaults of included sets" do
    @set.include_commands(@sub_set)
    image = @set.get_subject.get_image([:x, :y])
    image.x.should eql(3)
    image.y.should eql(200)
  end

  it "should not raise an error when included sets collide" do
    other_sub_set = Vizier::define_commands do
      command :subtract_w_from_z do
        subject_methods :w, :z

        action do |output|
          self.w += self.z
        end
      end

      subject_defaults(:w => 3000, :z => 4000)
    end
    @set.include_commands(@sub_set)
    @set.include_commands(other_sub_set)
    proc do
      @set.get_subject
    end.should_not raise_error
  end

  it "should raise an error when included sets collide" do
    other_sub_set = Vizier::define_commands do
      command :subject_x_from_y do
        subject_methods :x, :y

        action do |output|
          self.x += self.y
        end
      end

      subject_defaults(:x => 3000, :y => 4000)
    end
    @set.include_commands(@sub_set)
    @set.include_commands(other_sub_set)
    proc do
      @set.get_subject
    end.should raise_error(Vizier::CommandError)
  end
end

describe Vizier, "with mode commands" do
  before do
    subset = Vizier::define_commands do
      mode_command :other do
        subject_methods :record
        action do |output|
          self.record << 3
        end
      end

    end

    @interpreter = Vizier::QuickInterpreter.define_commands do
      mode_command :test do
        subject_methods :record
        action do |output|
          self.record << 1
        end
      end

      include_commands subset

      command :sub do
        include_commands StdCmd::Mode
        mode_command :test do
          subject_methods :record
          action do |output|
            self.record << 2
          end
        end
      end
      subject_defaults(:record => [])
    end
  end

  #Otherwise you get "mode mode exit" which is weird and bad
  it "should not allow access outside of the mode" do
    proc do
      @interpreter.process_input("sub test")
    end.should raise_error(Vizier::CommandException)
  end

  it "should allow access in the mode" do
    @interpreter.process_input("sub")
    @interpreter.process_input("test")
    @interpreter.process_input("exit")
    @interpreter.subject.record.should eql([2])
  end

  it "should include mode_commands from included sets" do
    @interpreter.process_input("other")
    @interpreter.subject.record.should eql([3])
  end
end

describe Vizier, "with aliased commands", :pending => "reintroduction of command_alias" do
  before do
    cmd = Vizier::Command.setup("i_am"){}

    @set = Vizier::define_commands do
      command :i_am do

      end
      command_alias("that", %w{i_am})
    end
  end

  it "should have identical commands with different names" do
    @set.find_command(["i_am"]).should eql(@set.find_command(["that"]))
  end
end

describe Vizier, "with contextualized inclusions", :pending => "more complicated compose" do
  before do
    sub_two = Vizier::define_commands do
      command :two do
        subject_methods :tag, :list
        action do |output|
          self.list << "two " + self.tag.to_s
        end
      end

      subject_defaults(:tag => 2)
    end

    sub_one = Vizier::define_commands do
      command :furthermore do
        include_commands sub_two, :context => :two
      end

      command :one do
        subject_methods :tag, :list
        action do |output|
          self.list.object_id
          self.list << "one " + subject.tag.to_s
        end
      end

      subject_defaults(:tag => 1)
    end

    @set = Vizier::define_commands do
      include_commands sub_one, :context => :one_top
      include_commands sub_two, :context => :two
      command :down do
        include_commands sub_one, :context => :one_bottom
      end

      subject_defaults(:list => [])
    end

    @interpreter = Vizier::QuickInterpreter.new
    @interpreter.command_set = @set
    @subject = @interpreter.subject_template
    @interpreter.subject = @subject
  end

  it "should keep items neatly in contexts" do
    @interpreter.process_input("one")
    @subject.list.should eql(["one 1"])
  end
end

describe Vizier::Command, :type => :command do
  describe "fresh" do
    command("test") {}
    subject({})

    ## Need to change this to "should create subclassed commands"
    #  it "should refuse to be set up twice" do
    #    proc do
    #    @cmd.setup("different") {}
    #    end.should raise_error(NoMethodError)
    #  end

    it "should return name properly" do
      cmd = command.new(execution_context)
      cmd.name.should eql("test")
    end

    it "should raise NoMethodError if a required argument is defined after optionals" do
      command.argument(:good_required, "Required")
      command.optional_argument(:optional, "Optional")
      proc do
        command.argument(:bad_required, "Required")
      end.should raise_error(NoMethodError)
    end
  end

  describe "with subject and local attributes and the default view" do
    command "test-view" do
      subject_methods :stuff

      view do
        {
          "stuff" => item{ subject.stuff },
          "just_ran" => "test-view"
        }
      end

      action do |output|
        self.stuff.replace "thing"
        puts "Progress"
      end
    end
    subject({:stuff => "stuff"})
    arguments({})

    it "should have subject methods in the view" do
      invocation.view["stuff"].should == "thing"
    end

    it "should have custom view additions in the view" do
      invocation.view["just_ran"].should == "test-view"
    end
  end

  describe "with a required argument" do
    command "test-required" do
      argument :need_me, "Needed"

      action {|s|}
    end
    subject({})

    it "should complain if it's run without having been given arguments" do
      proc do
        command.new(execution_context).go(results_collector)
      end.should raise_error(Vizier::CommandException)
    end

    it "should complain if it's given fewer arguments than it requires" do
      proc do
        execute_command(command, {})
      end.should raise_error(Vizier::OutOfArgumentsException)
    end
  end

  describe "A Command with a MultiArgument" do
    before do
      @interpreter = Vizier::QuickInterpreter::define_commands do
        command :test do
          multiword_argument("first") do |prefixes, term, subject|
            result = ["one"]
            (prefixes + [term]).each do |prefix|
              result = [] unless /^#{prefix}.*/ =~ "one"
            end
            result
          end

          argument("second") do |prefix, subject|
            return ["two"] if /^#{prefix}.*/ =~ "two"
            return []
          end
        end
      end
    end

    it "should complete with empty string" do
      @interpreter.complete_input("test ").list.should eql(%w{one two})
    end

    it "should complete with Multi three times" do
      @interpreter.complete_input("test one one one ").list.should eql(%w{one two})
    end

    it "should complete with Multi and then Proc" do
      @interpreter.complete_input("test one t").list.should eql(%w{two})
    end

    it "should complete with just Proc" do
      @interpreter.complete_input("test t").list.should eql(%w{two})
    end
  end

  describe "A Command with an alternating argument" do
    before do
      @cli = Vizier::QuickInterpreter::define_commands do
        command :test do
          alternating_argument :alternates  do
            argument :named_level, ["all", "some"]
            argument :percentage, 0..100
          end
        end
      end
    end

    it "should consume to array" do
      hash = @cli.cook_input("test all").arg_hash
      hash["named_level"].should eql("all")
      hash["percentage"].should eql(nil)
      hash["alternates"].should eql("all")
    end

    it "should consume to number" do
      hash = @cli.cook_input("test 34").arg_hash
      hash["named_level"].should eql(nil)
      hash["percentage"].should eql("34")
      hash["alternates"].should eql("34")
    end
  end

  describe "with tasks", :pending => "replace with real Tasks" do
    command "test" do
      subject_methods :value, :array
      action do |output|
        task 1 do
          subject.array << 1
        end
        if subject.value == 0
          pause
        end
        task 2 do
          subject.array << 2
        end
        task 3 do
          subject.array << 3
        end
      end
    end

    subject({ :array => [], :value => 0 })

    it "should stop and return information for resuming" do
      proc do
        execute_command(command, {})
      end.should raise_error(Vizier::ResumeFrom)

      vizier_subject.get_image([:array]).array.should eql([1])
    end

    it "should resume after the designated task" do
      resume_at = nil
      begin
        execute_command(command, {})
      rescue Vizier::ResumeFrom => rf
        resume_at = rf
      end

      resume_at.should_not be_nil
      vizier_subject.get_image([:array]).array.should eql([1])
      vizier_subject.value = 1

      cmd = command.new(execution_context)
      cmd.resume_from = resume_at.setup.task_id
      cmd.consume_hash({})
      cmd.go(results_collector)

      vizier_subject.get_image([:array]).array.should eql([1,2,3])
    end
  end

  describe "A chain of commands", :pending => "final decision about chaining" do
    before :all do
      @chainer = Vizier::Command.setup("chainer") do
        subject_methods :chain_cmd, :chain_args #never do this in production

        action do |output|
          chain(self.chain_cmd, self.chain_args)
        end
      end

      @chained = Vizier::Command.setup("chained") do
        subject_methods :record_array

        string_argument :one
        string_argument :two
        optional.string_argument :three

        action do |output|
          self.record_array.replace([one,two,three])
        end
      end

      chainer = @chainer
      chained = @chained

      @interpreter = Vizier::QuickInterpreter.define_commands do
        command chainer
        command chained
      end
    end

    before do
      @subject = @interpreter.subject_template
      @subject.record_array = []
    end

    def check_chaining(expected)
      @interpreter.subject = @subject
      @interpreter.process_input("chainer")
      @subject.get_image([:record_array]).record_array.should eql(expected)
    end

    it "should chain with a path to the command and hashed args" do
      @subject.chain_cmd = ["chained"]
      @subject.chain_args = {"one" => "1", "two" => "2", "three" => "3"}
      check_chaining(["1", "2", "3"])
    end

    it "should chain with a class and an arg hash" do
      @subject.chain_cmd = @chained
      @subject.chain_args = {"one" => "1", "two" => "2"}
      check_chaining(["1", "2", nil])
    end
  end

  describe Vizier::Command, "chaining from a deep subcommand", :pending => "final decision about chainging" do
    before do
      @interpreter = Vizier::QuickInterpreter.define_commands do
        command :test do
          subject_methods :record
          action do |output|
            self.record << 1
          end
        end

        command :sub do
          command :test do
            subject_methods :record
            action do |output|
              self.record << 2
            end
          end

          command :sub do
            command :test do
              subject_methods :record
              action do |output|
                self.record << 3
              end
            end

            command :sub do
              command :test do
                subject_methods :record
                action do |output|
                  self.record << 4
                end
              end
            end
          end
        end

        subject_defaults(:record => [])
      end
    end

    def sub_sub_sub_chain(depth, &block)
      Vizier::extend_command(@interpreter.command_set, %w{sub sub sub}) do
        command :chain do
          action(&block)
        end
      end
      @interpreter.process_input("sub sub sub chain")
      @interpreter.subject.record.should eql([depth])
    end

    it "should chain from immediate parent by default" do
      sub_sub_sub_chain(4) do |output|
        chain ["test"], {}
      end
    end

    it "should access immediate parent of parent" do
      sub_sub_sub_chain(3) do |output|
        chain up, ["test"], {}
      end
    end

    it "should access relative subcommands" do
      sub_sub_sub_chain(2) do |output|
        chain up(2), ["test"], {}
      end
    end

    it "should access the absolute root command set" do
      sub_sub_sub_chain(2) do |output|
        chain root, ["sub", "test"], {}
      end
    end
  end


  describe Vizier::Command, "with a subject argument basis" do
    before do
      @interpreter = Vizier::QuickInterpreter.define_commands do
        command :test do
          array_argument :item, (subject.item_nest.at(0){|i| i.map.to_s})

          subject_methods :item_nest, :picked

          action do |output|
            self.picked << item
          end
        end
      end

      @subject = @interpreter.subject_template
      @subject.picked = []
      @subject.item_nest = [[1,2,3,4]]
      @interpreter.subject = @subject
    end

    it "should use the subject to accept input" do
      @interpreter.process_input("test 1")
      @subject.picked.should eql(["1"])
    end

    it "should use the subject to reject input" do
      proc do
        @interpreter.process_input("test 7")
        @subject.picked
      end.should raise_error
    end
  end

  describe Vizier::Command, "that fans out to threads", :pending => "revisit collectors" do
    before do
      @interpreter = Vizier::QuickInterpreter.define_commands do
        command :test do
          number_argument :threads, 1..500
          action do |output|
            even = sub_collector
            even.begin_list("even")
            odd = sub_collector
            odd.begin_list("odd")
            fan_out(threads, 1..50) do |number|
              item number
              if (number % 2) == 0
                even.item number
              else
                odd.item number
              end
            end
          end
        end
      end
      require 'vizier/formatter/hash-array'
      @formatter = Vizier::Results::HashArrayFormatter.new
      fmtr = @formatter
      @interpreter.make_formatter do
        fmtr
      end
    end


    it "should fan out to one thread" do
      @interpreter.process_input("test 1")
      @formatter.structure[:array].length.should == 52
    end

    it "should fan out to a few threads" do
      @interpreter.process_input("test 5")
      @formatter.structure[:array].length.should == 52
    end

    it "should fan out to lots of threads" do
      @interpreter.process_input("test 50")
      @formatter.structure[:array].length.should == 52
    end
  end
end
