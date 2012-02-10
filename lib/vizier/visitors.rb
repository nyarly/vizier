require 'vizier/visitors/requirements-collector'
require 'vizier/visitors/completer'
require 'vizier/visitors/input-parser'
require 'vizier/visitors/shorthand-parser'

module Vizier::Visitors
  module Client
    def setup_visitor(klass, *first_states)
      visitor = visitor_class.new
      visitor.add_states(first_states)
      visitor
    end

    def visit(visitor_class, *first_state)
      setup_visitor(klass, *first_states).resolve
    end
  end
end
