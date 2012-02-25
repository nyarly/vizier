require 'vizier/executable_unit'

module Vizier
  class TaskList
    def initialize(*task_lists)
      @tasks = []
      task_lists.each do |list|
        list.each do |task|
          unless @tasks.include?(task)
            @tasks << task
          end
        end
      end
    end

    def executable?
      !@tasks.empty?
    end

    def executable(path, input_hash, subject, context)
      verify_image(subject)
      parsed_hash = parse_hash(input_hash, subject, context)
      task_instances = @tasks.map do |task|
        task.new(path, parsed_hash, subject.get_image(task.subject_requirements, context))
      end
      return ExecutableUnit.new(path, task_instances)
    end

    def undoable?
      @tasks.all? {|task| task.undoable?}
    end


    def subject_requirements
      @subject_requirements ||=
        begin
          @tasks.inject([]) do |list, task|
            list + task.subject_requirements
          end.uniq
        end
    end

    def subject_defaults
      @subject_defaults ||=
        begin
          @tasks.each_with_object({}) do |task, hash|
            hash.merge! task.subject_defaults
          end
        end
    end

    def argument_list
      @argument_list ||=
        begin
          list = []
          @tasks.each do |task|
            task.argument_list.each do |argument|
              idx = list.find_index do |listed|
                listed.name == argument.name
              end

              if idx.nil?
                list << argument
              else
                list[idx] = list[idx].merge(argument)
              end
            end
          end
          list.sort
        end
    end

    def argument_names
      @argument_names ||=
        begin
          argument_list.inject([]) do |allowed, argument|
            allowed += [*argument.name]
          end
        end
    end

    def string_keys(hash)
      new_hash = {}
      hash.keys.each do |name|
        new_hash[name.to_s] = hash[name]
      end
      return new_hash
    end

    def parse_hash(input_hash, subject, context)
      wrong_values = {}
      missing_names = []
      parsed_hash = {}

      input_hash = string_keys(input_hash)

      argument_list.each do |argument|
        begin
          #??? arguments need to be completely explicit about requirements now
          image = subject.get_image(argument.subject_requirements, context)
          parsed_hash.merge! argument.consume_hash(subject, input_hash)
        rescue ArgumentInvalidException => aie
          wrong_values.merge! aie.pairs
        rescue OutOfArgumentsException
          missing_names += ([*argument.name].find_all {|name| not parsed_hash.has_key?(name)})
        end
      end

      unless wrong_values.empty?
        raise ArgumentInvalidException.new(wrong_values)
      end

      unless missing_names.empty?
        raise OutOfArgumentsException, "Missing arguments: #{missing_names.join(", ")}"
      end

      return parsed_hash
    end

    def verify_image(subject)
      return if subject_requirements.nil?
      subject_requirements.each do |requirement|
        begin
          if Subject::UndefinedField === subject.send(requirement)
            raise CommandException, "\"#{name}\" requires \"#{requirement.to_s}\" to be set"
          end
        rescue NameError => ne
          raise CommandException, "\"#{name}\" requires subject to include \"#{requirement.to_s}\""
        end
      end
    end

  end
end
