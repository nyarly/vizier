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
  #Finally, Commands can't set fields - but the fields are the same for each
  #command, so they can change the fields.  For drastic changes, try
  #Array#replace or Hash#replace
  class Subject
    class UndefinedField; end
    Undefined = UndefinedField.new

    def initialize
      @fields = {}
      @contexts = {}
      @protected_subfields = Hash.new {|h,k| h[k] = []}
    end

    def initialize_copy(original)
      @fields = original.instance_variable_get("@fields").dup
      @contexts = original.instance_variable_get("@contexts").dup
      @protected_subfields = original.instance_variable_get("@protected_subfields").dup
      @fields.keys.each do |field_name|
        add_field_access(field_name)
      end
    end

    def required_fields(field_names, required_at=[])
      unless required_at.empty?
        unless @contexts.has_key?(required_at.first)
          create_context(required_at.first, Subject.new)
        end
        return @contexts[required_at.shift].required_fields(field_names,
                                                            required_at)
      end

      field_names.map! {|name| name.to_s}
      field_names -= instance_variables.map {|var| var.to_s.sub(/^@/, "")}
      bad_fields = field_names.find_all do |name|
        @contexts.has_key?(name.to_sym)
      end
      unless bad_fields.empty?
        raise CommandError, "#{bad_fields.join(", ")} are context names!"
      end

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

    def get_image(with_fields, in_context=[])
      in_context = in_context.dup
      fields = @fields.keys.inject({}) do |hash, key|
        hash[key] = self; hash
      end

      context = self
      until in_context.empty?
        protected_fields = @protected_subfields[in_context]
        context_name = in_context.shift.to_sym
        context = context.contexts[context_name]
        raise CommandError, "no context: #{context_name}" if context.nil?
        context.fields.each_key do |name|
          if not fields.key?(name) or
            fields[name] == Undefined or
            protected_fields.include?(name)

            fields[name] = context
          end
        end
      end

      with_fields.map! {|field| field.to_s}
      missing_fields = with_fields - fields.keys
      unless missing_fields.empty?
        raise CommandError, "Subject is missing fields: #{missing_fields.join(", ")}"
      end

      image = SubjectImage.new
      with_fields.each do |field|
        image.add_field(field, fields[field])
      end
      return image
    end

    def protect(*path)
      field_name = path.pop.to_s
      path.map! {|el| el.to_sym}
      @protected_subfields[path] << field_name
    end

    def merge(context, other)
      other.fields.keys.each do |name|
        add_field_access(name)
      end

      unless context.nil?
        context = context.to_sym
        if @contexts[context].nil?
          return create_context(context, other)
        else
          return @contexts[context].merge(nil, other)
        end
      end

      raise CommandError unless (defined_fields & other.defined_fields).empty?

      copy_fields(other)
    end

    def absorb(other)
      other.all_fields.each do |name|
        add_field_access(name)
      end

      copy_fields(other)
      copy_contexts(other)
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
    attr_reader :fields, :contexts

    def all_fields
      fields = @fields.keys
      @contexts.values.inject(fields) do |fields, context|
        fields + context.all_fields
      end
      return fields
    end

    def create_context(name, subject)
      raise CommandError if @fields.has_key?(name.to_s)
      @contexts[name] = subject
      (class << self; self; end).instance_eval do
        define_method("#{name}") do
          return @contexts[name]
        end
      end
      return self
    end

    def defined_fields
      @fields.keys.reject do |name|
        @fields[name] == Undefined
      end
    end

    def copy_fields(from)
      which = from.fields.keys
      required_fields(which)
      other_fields = from.instance_variable_get("@fields")
      which.each do |field|
        @fields[field] = other_fields[field]
      end
      return self
    end

    def copy_contexts(from)
      from.contexts.each_pair do |name, subject|
        if contexts[name].nil?
          contexts[name] = subject
        else
          contexts[name].merge(nil, subject)
        end
      end
    end

    def add_field(name)
      @fields[name] ||= Undefined
      add_field_access(name)
    end

    def add_field_access(name)
      (
        class << self; self; end
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


#This is the object type that's actually passed to a command.  It's
#populated using the subject_methods that the command declared, using values
#from the application Subject.
class SubjectImage
  def initialize
    @subjects = {}
    @accessible = []
  end
  #You shouldn't really need to ever call this - it's used by the
  #interpreter to set up the image before it's passed to the command
  def add_field(name, subject)
    name = name.to_s
    @accessible << name
    @subjects[name] = subject
    (
      class << self; self; end
    ).instance_eval do
      define_method(name) do
        return self[name]
      end

      define_method("#{name}=") do |value|
        return self[name] = value
      end
    end
  end

  def [](field)
    field = field.to_s
    if @accessible.include?(field)
      @subjects[field][field]
    else
      raise RangeError, "Field not accessible: #{field}"
    end
  end

  def []=(field, value)
    field = field.to_s
    if @accessible.include?(field)
      @subjects[field][field] = value
    else
      raise RangeError, "Field not accessible: #{field}"
    end
  end

  def get_image(fields, context=nil)
    #TODO: fail if I don't respond to a field
    return self
  end
end
end
