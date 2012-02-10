Gem::Specification.new do |spec|
  spec.name             = "vizier"
  spec.version          = "0.13"
  author_list = {
    "Judson Lester" => "nyarly@gmail.com"
  }
  spec.authors		= author_list.keys
  spec.email		= spec.authors.map {|name| author_list[name]}
  spec.summary		= "User interface framework for with a focus on a DSL for discrete commands"
  spec.description	= <<-EndDescription
  Vizier is a user interface framework.  Its focus is a DSL for defining
  commands, much like Rake or RSpec.  A default readline based terminal
  interpreter (complete with context sensitive tab completion, and the
  amenities of readline: history editing, etc) is included.  It could very
  well be adapted to interact with CGI or a GUI - both are planned.

  Vizier has a lot of very nice features.  First is the domain-specific
  language for defining commands and sets of commands.  Those sets can
  further be neatly composed into larger interfaces, so that useful or
  standard commands can be resued.  Optional application modes, much like
  Cisco's IOS, with a little bit more flexibility.  Arguments have their own
  sub-language, that allows them to provide interface hints (like tab
  completion) as well as input validation.

  On the output side of things, Vizier has a very flexible output
  capturing mechanism, which generates a tree of data as it's generated,
  even capturing writes to multiple places at once (even from multiple
  threads) and keeping everything straight.  Methods that normally write to
  stdout are interposed and fed into the tree, so you can hack in existing
  scripts with minimal adjustment.  The final output can be presented to the
  user in a number of formats, including contextual coloring and
  indentation, or even progress hashes.  XML is also provided, although it
  needs some work.  Templates are on the way.

  While you're developing your application, you might find the record and
  playback utilities useful.  cmdset-record will start up with your defaults
  for your command set, and spit out an interaction script.  Then you can
  replay the script against the live set with vizier-playback.  Great for ad
  hoc testing, usability surveys and general demos.
  EndDescription

  spec.rubyforge_project= spec.name.downcase
  spec.homepage        = "http://#{spec.rubyforge_project}.rubyforge.org/"
  spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=

  # Do this: y$@"
  # !!find lib bin doc spec spec_help -not -regex '.*\.sw.' -type f 2>/dev/null
  spec.files		= %w[
      lib/vizier.rb
      lib/vizier/spec/command.rb
      lib/vizier/command-set.rb
      lib/vizier/arguments.rb
      lib/vizier/visitors/shorthand-parser.rb
      lib/vizier/visitors/command-setup.rb
      lib/vizier/visitors/command-finder.rb
      lib/vizier/visitors/input-parser.rb
      lib/vizier/visitors/completer.rb
      lib/vizier/visitors/fileset-enricher.rb
      lib/vizier/visitors/requirements-collector.rb
      lib/vizier/visitors/base.rb
      lib/vizier/visitors/argument-addresser.rb
      lib/vizier/visitors/text-parser.rb
      lib/vizier/utils/template-populator.rb
      lib/vizier/arguments/string.rb
      lib/vizier/arguments/rest-of-line.rb
      lib/vizier/arguments/concatenated.rb
      lib/vizier/arguments/multi.rb
      lib/vizier/arguments/file.rb
      lib/vizier/arguments/base.rb
      lib/vizier/arguments/array.rb
      lib/vizier/arguments/proxy.rb
      lib/vizier/arguments/regexp.rb
      lib/vizier/arguments/fiddly.rb
      lib/vizier/arguments/alternating.rb
      lib/vizier/arguments/number.rb
      lib/vizier/arguments/proc.rb
      lib/vizier/interpreter/recording.rb
      lib/vizier/interpreter/text.rb
      lib/vizier/interpreter/base.rb
      lib/vizier/interpreter/quick.rb
      lib/vizier/subject.rb
      lib/vizier/result-list.rb
      lib/vizier/dsl.rb
      lib/vizier/visitors.rb
      lib/vizier/formatter/progress.rb
      lib/vizier/formatter/strategy.rb
      lib/vizier/formatter/hash-array.rb
      lib/vizier/formatter/base.rb
      lib/vizier/formatter/view.rb
      lib/vizier/formatter/xml.rb
      lib/vizier/template-builder.rb
      lib/vizier/command.rb
      lib/vizier/command-view.rb
      lib/vizier/standard-commands.rb
      lib/vizier/results.rb
      lib/vizier/argument-decorators/repeating.rb
      lib/vizier/argument-decorators/optional.rb
      lib/vizier/argument-decorators/settable.rb
      lib/vizier/argument-decorators/substring-match.rb
      lib/vizier/argument-decorators/base.rb
      lib/vizier/argument-decorators/named.rb
      lib/vizier/errors.rb
      bin/vizier-playback
      bin/vizier-record
      doc/README
      doc/GUIDED_TOUR
      doc/Specifications
      doc/argumentDSL
      spec/command-set.rb
      spec/arguments.rb
      spec/completions.rb
      spec/arguments/file.rb
      spec/arguments/base.rb
      spec/text-interpreter.rb
      spec/subject.rb
      spec/result-list.rb
      spec/ruby-assumptions.rb
      spec/fileset-setup.rb
      spec/command.rb
      spec/formatter.rb
      spec/standard-commands.rb
      spec/substring-matching.rb
      spec/results.rb
      spec_help/spec_helper.rb
      spec_help/gem_test_suite.rb
      spec_help/ungemmer.rb
      spec_help/file-sandbox.rb
  ]

  spec.test_file        = "spec_help/gem_test_suite.rb"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"

  if spec.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    spec.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      spec.add_development_dependency "corundum", "~> 0.0.1"
    else
      spec.add_development_dependency "corundum", "~> 0.0.1"
    end
  else
    spec.add_development_dependency "corundum", "~> 0.0.1"
  end

  spec.add_dependency("orichalcum", "= 0.6.0")
  spec.add_dependency("valise", "= 0.3")
  spec.add_dependency("stencil", "= 0.2")
  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main Vizier }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} RDoc"]

  #spec.add_dependency("postgres", ">= 0.7.1")

  spec.post_install_message = "Another tidy package brought to you by Judson"
end
