module Vizier
  #This object represents the subject of a command set.  To expose parts of
  #the application to the command set, commands should call subject_methods
  #with the names of methods it expects to use.
  #
  #Furthermore, Subject maintains the state of the command set, which helps
  #put all of the logic in the Command objects by letting them maintain
  #state in one place
  #
  #Subjects are very picky about their fields.  The motivation here is to
  #fail fast.  Commands can't access fields they don't declare with
  #DSL::CommandDefinition#subject_methods, and the interpreter will fail
  #fast unless the required fields have been assigned.
  #
  class Subject
    class UndefinedField; end
    Undefined = UndefinedField.new

    def initialize
      @fields = {}
    end

    def initialize_copy(original)
      @fields = original.fields.dup
      @fields.keys.each do |field_name|
        add_field_access(field_name)
      end
    end

    def required_fields(field_names)
      field_names.map! {|name| name.to_sym}
      field_names -= instance_variables.map {|var| var.to_s.sub(/^@/, "")}
      field_names.each do |field|
        add_field(field)
      end
    end

    def verify
      missing = @fields.keys.find_all do |var|
        UndefinedField === @fields[var]
      end
      unless missing.empty?
        missing.map! {|m| m.sub(/^@/,"")}
        raise RuntimeError, "Undefined subject field#{missing.length > 1 ? "s" : ""}: #{missing.join(", ")}"
      end
      return nil
    end

    def merge(other)
      other.fields.keys.each do |name|
        add_field_access(name)
      end

      raise CommandError unless (defined_fields & other.defined_fields).empty?

      copy_fields(other)
    end

    def [](name)
      if @fields.has_key?(name)
        @fields[name]
      else
        raise "Undefined field name: #{name}"
      end
    end

    def []=(name, value)
      if @fields.has_key?(name)
        @fields[name] = value
      else
        raise "Undefined field name: #{name}"
      end
    end

    protected
    attr_reader :fields

    def all_fields
      @fields.keys
    end

    def defined_fields
      @fields.keys.reject do |name|
        @fields[name] == Undefined
      end
    end

    def copy_fields(from)
      which = from.fields.keys
      required_fields(which)
      other_fields = from.fields
      which.each do |field|
        @fields[field] = other_fields[field]
      end
      return self
    end

    def add_field(name)
      @fields[name] ||= Undefined
      add_field_access(name)
    end

    def add_field_access(name)
      (
       class << self; self;
       end
      ).instance_eval do
        define_method("#{name}=") do |value|
          return @fields[name] = value
        end

        define_method(name) do
          return @fields[name]
        end
      end
    end
  end
end
