require "vizier/subject.rb"

describe Vizier::Subject do
  before do
    @subject = Vizier::Subject.new
  end

  it "should allow a field to be required" do
    proc do
      @subject.required_fields([:a_field])
    end.should_not raise_error
  end

  it "should allow multiple fields to be required" do
    proc do
      @subject.required_fields([:field1, :field2, :field3])
    end.should_not raise_error
  end
end

describe Vizier::Subject, "when merging with other subjects" do
  before do
    @subject = Vizier::Subject.new
    @subject.required_fields([:one, :two, :three])
    @subject.one = nil
    @subject.two = nil
    @sub_one = Vizier::Subject.new
    @sub_one.required_fields([:two])
  end

  it "should not allow a merge with colliding fields" do
    @sub_one.two = nil
    proc do
      @subject.merge(nil, @sub_one)
    end.should raise_error(Vizier::CommandError)
  end

  it "should allow a merge with colliding unfulfilled requirements" do
    proc do
      @subject.merge(nil, @sub_one)
    end.should_not raise_error
  end

  it "should allow a colliding merge into a context" do
    @sub_one.two = nil
    proc do
      @subject.merge(:sub, @sub_one)
    end.should_not raise_error
  end

  it "should not allow contexts to collide with fields" do
    proc do
      @subject.merge(:three, @sub_one)
    end.should raise_error(Vizier::CommandError)
  end

  it "should not allow fields to collide with contexts" do
    @subject.merge(:sub, @sub_one)

    proc do
      @subject.required_fields(["sub"])
    end.should raise_error(Vizier::CommandError)
  end
end

describe Vizier::Subject, "with contextual sub-subjects" do
  before do
    @subject = Vizier::Subject.new
    @subject.required_fields([:vegetable, :nut])

    @sub_one = Vizier::Subject.new
    @sub_one.required_fields([:fruit, :nut])
    @sub_one.fruit = 2
    @sub_one.nut = "cashew"

    @subject.merge(:one, @sub_one)

    @sub_two = Vizier::Subject.new
    @sub_two.required_fields([:fruit, :nut])
    @sub_two.fruit = 3
    @sub_two.nut = "chestnut"

    @subject.merge(:two, @sub_one)

    @subject.vegetable = 1
    @subject.protect(:one, :nut)
    @subject.nut = "almond"
  end

  it "should project an image without context" do
    image = @subject.get_image([:vegetable, :nut])
    image.vegetable.should eql(1)
    image.nut.should eql("almond")
  end

  it "should not absorb fields from contexts" do
    proc do
      @subject.get_image([:fruit])
    end.should raise_error(Vizier::CommandError)
  end

  it "should project an image within a context" do
    image = @subject.get_image([:fruit, :vegetable, :nut], [:one])
    image.vegetable.should eql(1)
    image.fruit.should eql(2)
    image.nut.should eql("cashew")
  end

  it "should allow assignment of fields within contexts" do
    @subject.one.nut = "pistacio"
    @subject.get_image([:nut], [:one]).nut.should eql("pistacio")
    @subject.get_image([:nut], [:two]).nut.should eql("almond")
    @subject.get_image([:nut]).nut.should eql("almond")
  end

  it "should allow image assignment back to contexts" do
    image = @subject.get_image([:fruit, :vegetable, :nut], [:one])
    image.nut = "pistacio"
    image.vegetable = 17

    @subject.vegetable.should == 17
    @sub_one.nut.should == "pistacio"
    @subject.nut.should == "almond"
    @sub_two.nut.should == "chestnut"
  end
end

describe Vizier::Subject, "with required fields" do
  before do
    @subject = Vizier::Subject.new
    @subject.required_fields([:a_field])
    @subject.required_fields([:another_field, :yaf])
  end

  it "should not verify if fields are not set" do
    proc do
      @subject.verify
    end.should raise_error(RuntimeError)
  end

  it "should not verify if some fields are not set" do
    @subject.a_field = nil
    @subject.another_field = nil
    proc do
      @subject.verify
    end.should raise_error(RuntimeError)
  end

  it "should verify if all fields are set" do
    @subject.a_field = 1
    @subject.another_field = :something
    @subject.yaf = [:some, "more", 'stuff']
    proc do
      @subject.verify
    end.should_not raise_error
  end

  it "should spawn SubjectImage objects that do respond to readers" do
    @subject.a_field = 1
    @subject.another_field = :something
    @subject.yaf = [:some, "more", 'stuff']

    image = @subject.get_image([:a_field, :another_field, :yaf])

    image.a_field.should eql(1)
    image.another_field.should eql(:something)
    image.yaf.should eql([:some, "more", 'stuff'])
  end
end
