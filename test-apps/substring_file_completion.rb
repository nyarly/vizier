$:.unshift File::expand_path("../../lib", __FILE__)
require 'vizier'
require 'valise'

int = Vizier::TextInterpreter.new

int.command_set = Vizier::CommandSet::define_commands do
  command :test do
    substring_complete.file_argument :file, :accept => :is_file, :prune_patterns => [%r{/[.]}, %r{public/system}]

    optional.argument :line, "Line Number"

    doesnt_undo

    action do
    end

    view do
      {:selection => item{file}}
    end
  end
end

int.subject = int.subject_template
int.subject.interpreter_behavior[:debug_commands] = true
int.template_files = Valise::DefinedDefaults.new

int.go
