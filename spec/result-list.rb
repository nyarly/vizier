require 'vizier/result-list'

module ListUtil
  def list(name, *list)
    Vizier::Results::List.new(name, list)
  end
end

describe Vizier::Results::ListIterator do
  include ListUtil

  before do
    @list = list("1", :a, list("2b", :a, list("3b", :a, :b, :c), "c"), list("2c"), :d, :e)
    @iter = Vizier::Results::ListIterator.new(@list)
  end

  it "should traverse list in tree order" do
    @iter.reject{|item| Vizier::Results::ListEnd === item}.map do |item|
      item.to_s
    end.should eql(["1", "a", "2b", "a", "3b", "a", "b", "c", "c", "2c", "d", "e"])
  end
end

describe Vizier::Results::List do
  include ListUtil

  before do
    @list = list("1", list("2", :a, "b", :c, "d"), :a, list("3"))
  end

  it "should compare to similar lists as similar" do
    @list.should eql(list("1", list("2", :a, "b", :c, "d"), :a, list("3")))
  end

  it "should compare to different lists as different" do
    @list.should_not eql(list("1", list("2", :a, "b", 3, "d"), :a, list("3")))
  end

  it "should filter lists by path" do
    list("", @list).filter(["1", "2", :a]).should eql(list("", list("1", list("2", :a))))
  end

  it "should raise NoMatch for unmatched path" do
    proc do
      list("", @list).filter(["bogus"])
    end.should raise_error(Vizier::Results::List::NoMatch)
  end

  it "should filter lists with wildcard list" do
    list("", @list).filter(["1", :*, :a]).should eql(list("", list("1", list("2", :a))))
  end

  it "should treat lonely double-star as an identity" do
    list("", @list).filter([:**]).should eql(list("", @list))
  end

  it "should filter lists with double-star lists" do
    list("", @list).filter([:**, :a]).should eql(list("", list("1", list("2", :a), :a)))
  end

  it "should filter lists with wildcard item" do
    list("", @list).filter(["1", "2", :*]).should eql(list("", list("1", list("2", :a, "b", :c, "d"))))
  end

end
