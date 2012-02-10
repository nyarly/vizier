require 'vizier/formatter/base'

module Vizier::Results
  class TextProgressFormatter < Formatter
    include Formatter::Styler
    def initialize(out = ::Vizier::raw_stdout)
      @out_to = out
      @spinner = %w{/ - \ |}
      @backup = ""
      super()
    end

    def closed_begin_list(list)
      puts unless list.depth == 0
      @backup = ""
    end

    def spin_once(item)
      spin = @spinner.shift
      @out_to.print style(@backup + spin, item.options)
      @spinner.push spin
      @backup = "\b"
      @out_to.flush
    end

    def saw_item(item)
      spin_once(item)
    end

    def saw_end_list(list)
      spin_once(item)
    end
  end
end
