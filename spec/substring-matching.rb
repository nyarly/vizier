require 'vizier/argument-decorators/substring-match'

#XXX: Should be testing completion, not mark_ranges
describe Vizier::SubstringMatch do
  before :each do
    @matcher = Vizier::SubstringMatch::SubstringMatcher.new("WXYZ",[])
    @regex = @matcher.instance_variable_get("@regex")
  end

  it "should match the correct ranges" do
    @matcher.mark_ranges(@regex.match("aaaWXaYaaaZaaa")).should == [(3...5), (6...7), (10...11)]
  end
end
