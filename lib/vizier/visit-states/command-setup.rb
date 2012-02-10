require 'vizier/visit-states'

module Vizier::VisitStates
  class CommandSetup < CommandInstantiator
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
