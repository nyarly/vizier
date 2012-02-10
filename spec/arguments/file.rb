require 'vizier/arguments/file'

describe Vizier::FileArgument do
  before do
    @argument = Vizier::FileArgument.new(:test)
    @me = File::expand_path(__FILE__)
    @rel = %r{^#{ENV["PWD"]}/(.*)}.match(@me)[1]
    @subject = mock("Subject")
  end

  it "should complete with me" do
    @argument.complete([], @me[0..-2], @subject).list.should eql([@me])
  end

  it "should complete with relative path" do
    @argument.complete([], @rel[0..-2], @subject).list.should eql([@rel])
  end

  it "should complete with relative dir" do
    completions = @argument.complete([], File::dirname(@rel) + "/", @subject).list

    completions.should_not == []
  end

  it "should complete at root dir" do
    completions = @argument.complete([], "/et", @subject).list
    completions.find_all{|cmpl| %r{./.} =~ cmpl}.should == []
    completions.should include("/etc/")
  end

  it "should complete with list if prefix empty" do
    @argument.complete([], "", @subject).list.should_not be_empty
  end

  it "should validate me" do
    @argument.validate(@me, @subject).should eql(true)
  end

  it "should validate absolute paths" do
    @argument.validate(File.expand_path(@me), @subject).should eql(true)
  end

  it "should not validate garbage" do
    @argument.validate("somegarbage", @subject).should eql(false)
  end

  it "should not validate directory" do
    @argument.validate(File.dirname(@me), @subject).should eql(false)
  end
end
