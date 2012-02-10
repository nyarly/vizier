describe "The Ruby interpreter" do

  it "should provide backtraces in an unsurprising format" do
    harness = Object.new
    def harness.test_method
      return /:in `([^']*)/.match(caller(0)[0])[1]
    end

    harness.test_method.should == "test_method"
  end
end
