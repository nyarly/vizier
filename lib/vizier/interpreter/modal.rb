module Vizier
  module ModalInterpreter
    def normalized_input(raw_input)
      result = VisitStates::CommandSetup.canonicalize(super)
      result.command_path = current_command_path.command_path +
        result.command_path
      result.arg_hash = default_arg_hash.merge(result.arg_hash)
    end

    #  Puts a CommandSet ahead of the current one for processing.  Useful for
    #  command
    #  modes, like Cisco's IOS with configure modes, et al.
    def push_mode(mode, root_command)
      #TODO: store a command setup to use as the root of future searches
      unless Command === mode
        raise RuntimeError, "Sub-modes must be Commands!"
      end

      sub_modes.push([mode, root_command])
      return nil
    end

    #  The compliment to #push_mode.  Removes the most recent command set.
    def pop_mode
      sub_modes.pop
      return nil
    end

    def current_command_set
      return super if @sub_modes.empty?
      return @sub_modes.last[0]
    end

    def default_arg_hash
      return {} if @sub_modes.empty?
      return @sub_modes.last[1].arg_hash
    end

    def current_nesting
      return [] if @sub_modes.empty?
      return @sub_modes.map{|item| item[1]}
    end
  end
end
