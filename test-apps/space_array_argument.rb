require 'command-set'
require 'valise'

cs = Command::CommandSet::define_commands do
  command :test do
    array_argument :arr, [
      "This is a very long option",
      "This is another long options"
    ]

    action do
    end

    view do
      {:selection => item{arr}}
    end
  end
end

int = Command::TextInterpreter.new
int.command_set = cs

int.subject = int.subject_template
int.template_files = Valise.new(".")

int.go
