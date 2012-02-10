require 'stencil/dynamic-template'
require 'stencil/directives/text'

module Vizier
  class ViewTemplate < ::Stencil::DynamicTemplate
    register :command_view

    item "[;=;]"
    list "[;each @ i;][;reapply @i;][;if @i+1;][;nl;][;end;][;end;]"
    hash "[;each pair h;][;if not @h:key == 'results';][;= @h:key;]: [;reapply @h:value;][;end;][;nl;][;end;]"
  end
end
