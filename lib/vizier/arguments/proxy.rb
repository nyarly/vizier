require "vizier/arguments/base"
require "vizier/visitors"

module Vizier
  class ProxyArgument < Argument
    register "proxy"

    def initialize(name, setup)
      super(name)

      @address = nil
      @fixup = nil

      if Proc === setup
        setup[self]
      else
        @address = setup.to_s
      end
      @fixup ||= proc {|arg| arg}
    end

    attr_accessor :address, :fixup

    #XXX This wants to be inverted
    def principal_from_state(state)
      argument_address = state.arg_hash[@address]
      return nil if argument_address.nil?
      root = state.set_nesting.first

      principal = locate_principal(argument_address, root)
      return nil,nil if principal.nil?

      new_state = state.dup
      new_state.command_path = argument_address[0..-2]
      new_state.arg_hash.delete(principal.name)
      return principal, new_state
    end

    def locate_principal(argument_address, root)
      return nil if argument_address.nil?
      setting_path = argument_address[0..-2]
      setting_name = argument_address[-1]

      finder = Visitors::ArgumentAddresser.go(setting_path, [Settable], root)
      principal = finder.get_argument(setting_name)
      return nil if principal.nil?
      return @fixup[principal]
    end

    def alias_arg_hash(name, states)
      states.each do |state|
        state.arg_hash[@name] = state.arg_hash.delete(name)
      end
      return states
    end

    def consume_hash(subject, hash)
      argument_address = hash[@address]
      root = subject.command_set

      principal = locate_principal(argument_address, root)

      return {} if principal.nil?
      proxy_hash = principal.consume_hash(subject, {principal.name => hash[name]})
      hash[name] = proxy_hash[principal.name]
      return hash
    end

    def state_complete(state, subject)
      principal,new_state = *principal_from_state(state)
      return [] if principal.nil?
      principal.state_complete(new_state, subject)
    end

    def state_consume(state, subject)
      principal,new_state = *principal_from_state(state)
      return [] if principal.nil?
      states = principal.state_consume(new_state, subject)
      return alias_arg_hash(principal.name, states)
    end
  end
end
