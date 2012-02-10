require 'vizier'
require 'valise'
require 'file-sandbox'

describe "Tricky completion" do
  describe "fuzzy file completion with optional string" do
    include FileSandbox

    before do
      @sandbox.new :file => "here/is_a/file.rb"
      @sandbox.new :file => "help/my/file.rb"
      @sandbox.new :file => "here/is_a/filer.rb"
      dir = @sandbox.root

      @command_set = Vizier::define_commands do
        command :test do
          fuzzy_complete.file_argument :file,
            :accept => :not_dir,
            :dir => dir

          optional.argument :line, "Line Number"

          doesnt_undo

          action do
          end

          view do
            {:selection => item{file}}
          end
        end
      end
      @subject = mock(Vizier::Subject)
      @subject.stub!(:get_image, @subject)
    end

    it "should complete 'test '" do
      @command_set.completion_list('test ', @subject).list.should
        include "here/is_a/file.rb", "here/is_a/filer.rb", "help/my/file.rb"
    end

    it "should complete 'test h'" do
      @command_set.completion_list("test h", @subject).list.should
        include("here/is_a/file.rb", "here/is_a/filer.rb", "help/my/file.rb")
    end
  end
end
