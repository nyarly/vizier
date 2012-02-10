require 'vizier/formatter/base'

module Vizier::Results
  class ViewFormatter < Formatter
    def initialize
      super()
      @view = []
      @caret = [@view]
    end

    attr_reader :view

    def closed_begin_list(list)
      arr = []
      @caret.last << arr
      @caret.push arr
    end

    def closed_end_list(list)
      @caret.pop
    end

    def closed_item(item)
      @caret.last << item.value
    end

    def finish
    end
  end
end
