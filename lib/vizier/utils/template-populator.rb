require 'valise'

module Vizier
  class TemplatePopulator
    def initialize(command_set, template_root)
      @command_set = command_set
      @valise = Valise.new([template_root])
      @interpreters = []
      default_interpreters
    end

    def clear_interpreters
      @interpreters.clear
    end

    def default_interpreters
      %w{Text Quick}.each do |int|
        register_interpreter(int)
      end
    end

    def register_interpreter(klass)
      if String === klass
        require "vizier/interpreter/" + klass.downcase
        klass = Vizier::const_get(klass + "Interpreter")
      end

      @interpreters << klass
    end

    def all_templates
      hash = {}
      @interpreters.each do |klass|
        hash.merge(klass.default_template_hash)
      end
      return hash
    end

    def go
      defaults = Valise::DefinedDefaults.new
      @command_set.default_files(defaults, all_templates)
      destination = Valise::SearchRoot.new(@template_root)
      defaults.each do |item|
        destination.insert(item)
      end
    end
  end
end
