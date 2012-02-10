require 'vizier/formatter/base'

module Vizier::Results
  #A trivial and obvious Formatter: produces well-formed XML fragments based on events.  It even
  #indents.  Might be handy for more complicated output processing, since you could feed the document
  #to a XSLT processor.
  class XMLFormatter < TextFormatter
    def initialize(out = nil, err = nil, indent="  ", newline="\n")
      super(out, err)
      @indent = indent
      @newline = newline
      @indent_level=0
    end

    def line(string)
      print "#{@indent * @indent_level}#{string}#@newline"
    end

    def closed_begin_list(name)
      line "<#{name}#{xmlize_options(name)}>"
      @indent_level += 1
    end

    def closed_item(value)
      line "<item value=\"#{value}\"#{xmlize_options(value)} />"
    end

    def closed_end_list(name)
      @indent_level -= 1
      if @indent_level < 0
        @indent_level = 0
        return
      end
      line "</#{name}>"
    end

    private

    def flatten_value(value)
      case value
      when Hash
        return value.map do |name, value|
            "#{name}: #{value}"
        end.join("; ")
      else
        return value.to_s
      end
    end

    def xmlize_options(item)
      item.options.inject("") do |string, (name, value)|
        string + " #{name}=\"#{flatten_value(value)}\""
      end
    end
  end
end
