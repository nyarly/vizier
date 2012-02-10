

module Vizier::Tasks
  class Quit < Base
    def action(out)
      exit
    end
  end

  class SaveAll < Base
    before Quit
    def action(out)
    end
  end

  class SaveDoc < Base
    file_argument :file

    def action(out)
      @subject_image[:editor].save(file)
    end
  end

  SaveDoc.before SaveAll
end

sub_app = command "sub_app" do
  command "nifty" do
    command "keen"
    ...
  end

  command "gnarly" {}
  command "ginchy" {}
end

command "my_app" do
  command "quit" do
    docs "Quits the app"

    task "Quit"
  end

  command "save" do
    docs "Saves a file"

    task "SaveDoc"
  end

  add_command sub_app

  add_from sub_app, ["nifty", "keen"], "gnarly"
  #adds "keen" and "gnarly" here

  command "sub_app" do
    add_from sub_app #adds all from sub_app
  end
end

app = Interpreter::Text.new
app.command_set = my_app.described
app.renderer = Vizier::Renderer::Stencil.new(my_app.file_set)

####

my_app = Command.new("my_app")
quit = Command.new("quit")
quit.documentation = "Quits the app"
quit.task(Vizier::Tasks::Quit)
my_app.add_child(quit)

...
my_app.add_child(sub_app.find_child("nifty", "keen"))
...
