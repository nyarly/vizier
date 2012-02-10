module Vizier
  #A thin wrapper on Array to maintain undo/redo state.
  class UndoStack
    def initialize()
      @stack = []
      @now = 0
    end

    def add(cmd)
      @stack.slice!(0,@now)
      @now=0
      @stack.unshift(cmd)
    end

    def get_undo
      if @now > (@stack.length - 1) or @stack.length == 0
        raise CommandException, "No more commands to undo"
      end
      cmd = @stack[@now]
      @now+=1
      return cmd
    end

    def get_redo
      if @now <= 0
        raise CommandException, "Can't redo"
      end
      @now-=1
      return @stack[@now]
    end
  end
end
