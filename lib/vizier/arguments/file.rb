require 'vizier/errors'
require 'vizier/arguments/base'

module Vizier
  #File access. Completes paths, validates file options.
  #You create a FileArgument either with an optional  hash of options, or
  #a block that evaluates whether or not a path is acceptable.
  #
  #The default options hash looks like:
  #
  # :prune_patterns => [/^\./],  #regexs of paths to eliminate from
  #                              #completion
  # :dirs => [ENV['PWD']],       #works essentially the PATH env variable
  # :acceptor => proc do |path|  #Is a good path?
  #   return (File.exists?(path) and not File.directory?(path))
  # end                          #The default wants existent non-dirs
  #

  #Requires existence, opens file for you (be sure to close it)
  #Or hands you a file wrapper - obj.open {|file| }
  #Valise component?
  class FileArgument < Argument
    register "file"

    class Traverser

      class Expires
        Lifetime = 20

        def initialize
          @dies = Time.now + Lifetime
          @value = get
        end

        def value
          if Time.now > @dies
            @dies = Time.now + Lifetime
            return @value = get
          else
            return @value
          end
        end
      end

      class LStat < Expires
        def initialize(path)
          @path = path
          super()
        end

        def get
          File.lstat(@path)
        end
      end

      class DirEntries < Expires
        def initialize(path)
          @path = path
          super()
        end

        Dotpaths = %w{. ..}

        def get
          Dir::entries(@path) - Dotpaths
        end
      end

      #TODO: dealing with changes to FS?
      def initialize
        @lstat = Hash.new{|h,k| h[k] = LStat.new(k)}
        dotpaths = %w{. ..}
        @dirs = Hash.new do |h,k|
          h[k] = DirEntries.new(k)
        end
      end

      def stat(full_path)
        begin
          return @lstat[full_path].value
        rescue
          return nil
        end
      end

      def files_in_dir(dirpath)
        @dirs[dirpath].value
      end
    end

    def self.traverser
      return @traverser ||= Traverser.new
    end


    class FileEnumerator

      #To elaborate: there's a lot of good research on PQueue and
      #their implementation.  This one is simple but likely slower than it
      #could be.
      #Where to start: http://en.wikipedia.org/wiki/Priority_queue
      #TL;DR: heaps are popular when they're available
      class PQueue
        Item = Struct.new(:prio, :values)

        def initialize
          @queue = []
        end

        def inspect
          @queue.map {|item| item.values}.flatten.inspect
        end

        def add(prio, *values)
          insert_at = -1
          @queue.each_with_index do |pair, index|
            if pair.prio == prio
              pair.values += values
              return nil
            end

            if pair.prio > prio
              insert_at = index
              break
            end
          end
          @queue.insert(insert_at, Item.new(prio, values))
          return nil
        end

        PopFrom = 0
        def pop
          return nil if @queue.empty?
          while @queue[PopFrom].values.empty?
            @queue.delete_at(PopFrom)
            return nil if @queue.empty?
          end
          value = @queue[PopFrom].values.shift
          return value
        end
      end

      def self.absolute_path?(file)
      end

      def initialize(options)
        path = options[:dir]
        @root = path
        @search_paths = Dir::entries(@root) - %w{. ..}
        @prune = [*options[:prune_patterns]]
      end

      def traverser
        FileArgument::traverser
      end

      def each
        queue = PQueue.new
        queue.add(0.5, *@search_paths)
        while path = queue.pop

          full_path = File::join(@root, path)
          next if @prune.find{|pat| pat =~ full_path}

          stat = traverser.stat(full_path)
          if stat.nil?
            next
          elsif stat.directory?
            possible = offered_path(path) + "/"

            rating = yield(possible)

            if rating > 0
              dir_paths = traverser.files_in_dir(full_path).map{|sub| File::join(path, sub)}
              queue.add(1.0 / rating * possible.length, *dir_paths)
            end
          else
            possible = offered_path(path)

            yield(possible)
          end
        end
      end

      def offered_path(path)
        path.dup.taint
      end
    end

    class AbsoluteFileEnumerator < FileEnumerator
      def offered_path(path)
        File::join(@root, path)
      end
    end

    class FileMatcher < CompletionMatcher
      def initialize(prefix, list)
        super

        segments = prefix.split(File::Separator)

        if segments[0] == ""
          segments[0..1] = ["/" + segments[1]]
        end

        segments = [".*"] if segments.empty?

        segments[-1] = "(" + segments[-1] + ")"

        path_exp = segments.reverse.inject do |subexp, segment|
          "#{segment}(?:/#{subexp})?"
        end

        @mark_range = (0..path_exp.length)
        @regex = %r{^(#{path_exp}[^/]*/?)(.*)?}
      end

      def rate(match)
        if match.nil?
          -1.0
        elsif not (match[3].nil? or match[3].empty?)
          -1.0
        elsif not (match[2].nil? or match[2].empty?)
          1.0
        else
          0.5
        end
      end
    end

    module Acceptors
      module IsFile
        def accept(path)
          return (File.exists?(path) and not File.directory?(path))
        end
      end

      module IsDirectory
        def accept(path)
          return (File.exists?(path) and File.directory?(path))
        end
      end

      module NotDirectory
        def accept(path)
          return (File::exists?(File::dirname(path)) and not File.directory?(path))
        end
      end

      module Any
        def accept(path)
          return true
        end
      end

      module Exists
        def accept(path)
          return File.exists?(path)
        end
      end
    end


    AcceptorModules = {
      :is_file => Acceptors::IsFile,
      :is_dir => Acceptors::IsDirectory,
      :not_dir => Acceptors::NotDirectory,
      :is_directory => Acceptors::IsDirectory,
      :not_directory => Acceptors::NotDirectory,
      :any => Acceptors::Any,
      :exists => Acceptors::Exists
    }

    #defaults
    include Acceptors::IsFile

    def self.default_options
      {
        :prune_patterns => [/^\./],
        :dir => ENV['PWD'],
      }
    end

    def default_options
      @default_options ||= self.class.default_options.dup
    end

    def initialize(name, basis=nil)
      super
      if Hash === basis
        if basis.has_key? :accept and AcceptorModules.has_key?(basis[:accept])
          extend AcceptorModules[basis[:accept]]
        end
      end
    end

    def basis(subject=nil)
      options = super(subject) || {}
      if Hash === options
        options = default_options.merge(options)
        options.each_pair do |name, val|
          if DSL::Argument::SubjectDeferral === val
            options[name] = val.realize(subject)
          end
          if options[name].nil?
            options[name] = self.class.default_options[name]
          end
        end
      elsif Proc === options
        acceptor = proc &options
        options = self.class.default_options.dup
        options[:acceptor_proc] = acceptor
      else
        raise "File argument needs hash or proc!"
      end
      return options
    end

    def possible_completions(prefix, subject)
      if (!File::ALT_SEPARATOR && prefix =~ %r{^/}) or
        prefix =~ %r{^(?:[\/]|[A-Za-z]:[\/]?)}
        return AbsoluteFileEnumerator.new(:dir => File::dirname(prefix))
      else
        return FileEnumerator.new(basis(subject))
      end
    end

    def completion_matcher(terms, prefix, list, subject)
      return FileMatcher.new(prefix, list)
    end

    def fs
      File::Separator
    end

    def validate(term, subject)
      options = basis(subject)
      if(%r{^#{fs}} =~ term)
        return accept(term)
      end

      found = options[:dir].find do |dir|
        accept(File.join(dir, term))
      end

      return (not found.nil?)
    end
  end
end
