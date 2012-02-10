require "vizier/arguments"

describe Vizier::Argument, :type => :argument do
  describe "method:has_feature?" do
    describe "on fuzzy_complete.named.file_argument" do
      before :each do
        fuzzy_complete.named.file_argument :test
      end

      it "should not have Optional" do
        argument(:test).should_not have_feature Vizier::Optional
      end

      it "should not have Multi" do
        argument(:test).should_not have_feature Vizier::Repeating
      end

      it "should not have Proc" do
        argument(:test).should_not have_feature Vizier::ProcArgument
      end

      it "should have SubstringMatch" do
        argument(:test).should have_feature Vizier::SubstringMatch
      end

      it "should have Named" do
        argument(:test).should have_feature Vizier::Named
      end

      it "should have File" do
        argument(:test).should have_feature Vizier::FileArgument
      end

    end

    describe "on optional.multi.proc_argument" do
      before :each do
        optional.repeating.proc_argument(:test){|a,b|}
      end

      it "should have Optional" do
        argument(:test).should have_feature Vizier::Optional
      end

      it "should have Multi" do
        argument(:test).should have_feature Vizier::Repeating
      end

      it "should have Proc" do
        argument(:test).should have_feature Vizier::ProcArgument
      end

      it "should not have SubstringMatch" do
        argument(:test).should_not have_feature Vizier::SubstringMatch
      end

      it "should not have Named" do
        argument(:test).should_not have_feature Vizier::Named
      end

      it "should not have File" do
        argument(:test).should_not have_feature Vizier::FileArgument
      end


    end

  end
end
