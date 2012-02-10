require 'thread'

module Vizier
  class Registry
    class << self
      def global
        @global ||= self.new
      end

      def thread_local
        Thread.current["vizier/registry"] ||= self.new
      end

      def register(&block)
        thread_local.register(&block)
        thread_local.transfer(global)
      end
    end

    def initialize
      @descriptions = {}
      @by_file = {}
      @observers = []
    end

    #XXX Two step register?
    def register(file = nil)
      file ||= caller(0)[1].sub(/:.*/,'')
      description = yield
      add(file, description.described.name, description)
    end

    def notify_registrations(path, &block)
      require path
      global.commands_from_file(path, &block)
    end

    def commands_from_file(path)
      @by_file[normalized_path(path)].each do |description|
        yield description
      end
    end

    def transfer(target)
      Thread.exclusive do
        @by_file.each_pair do |path, description|
          target.add(path, description.described.name, description)
        end
        @descriptions.clear
        @by_file.clear
      end
    end

    def normalized_path(path)
      File::expand_path(path)
    end

    def add(path, name, description)
      @descriptions[name] = description #explode on collide?
      @by_file[normalized_path(path)] = description
    end
  end
end
