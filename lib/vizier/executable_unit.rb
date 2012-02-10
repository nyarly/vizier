module Vizier
  class ExecutableUnit
    def initialize(path, tasks)
      @path = path
      @tasks = tasks
      @current_task = 0
      @view = { "results" => [], "tasks" => {}, "subject" => {} }
      @tasks.each do |task|
        @view["tasks"][task.name] = {}
      end
    end

    attr_reader :view, :path

    def undoable?
      @undoable ||= @tasks.all?{|task| task.respond_to?(:undo)}
    end

    def started?
      @current_task > 0
    end

    def finished?
      @current_task >= @tasks.length
    end

    #XXX include task instances
    def inspect
      return "#<EU:#{path.join("/")}>:#{"%#x" % self.object_id}"
    rescue
      super
    end

    def go(collector)
      @tasks.each.with_index(@current_task) do |task, idx|
        @current_task = idx
        task.execute(@view["tasks"][task.name])
        @view["subject"].merge! task.subject_view
      end

      @current_task = @tasks.length
    end

    def undo(collector)
      @tasks.reverse_each.with_index(length - @current_task) do |task, idx|
        @current_task = length - idx
        task.reverse(@view["tasks"][task.name])
        @view["subject"].merge! task.subject_view
      end
      @current_task = 0
    end

    def join_undo(stack)
      stack.add(self) if undoable?
    end
  end
end
