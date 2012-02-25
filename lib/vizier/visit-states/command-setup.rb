require 'vizier/visit-states'

module Vizier::VisitStates
  class CommandSetup < CommandInstantiator
    def self.canonicalize(something)
      case something
      when self
        return something
      when Array
        path, arg_hash = *something
        node = command_visit(Visitors::Command, VisitStates::CommandPathState, path)
        command_setup = new(node)
        command_setup.arg_hash = arg_hash
        return command_setup
      else
        raise TypeError, "Can't make a CommandSetup out of #{something.class.name}: #{something.inspect}"
      end
    end

    def initialize(node, input)
      super
      @task_id = nil
    end
    attr_accessor :node, :command_path, :arg_hash, :task_id

    #XXX bring back pause/resume
#    def command_instance(command_set, subject)
#      command = super
#      #command.resume_from = @task_id
#      command
#    end
  end

  #XXX: Collapse into superclass?
  class AnchoredCommandSetup < CommandSetup
    def initialize(command_set, input)
      super(nil, input)
      @anchored_at = command_set
    end

    attr_accessor :anchored_at

    def command_instance(command_set, subject)
      if @node.nil?
        @node = @anchored_at.find_command(@command_path.dup)
      end
      super
    end
  end
end
