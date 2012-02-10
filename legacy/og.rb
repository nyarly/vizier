require 'vizier/command'
require 'vizier/arguments'
require 'facet/kernel/constant'

module Vizier
  class OgArgument < Argument
    def initialize(name, klass, find_by="name", options={})
      super(name)
      @klass = klass
      @key = find_by
      @options = options
    end

    def complete(prefix, subject)
      entities = @klass.find(@options.merge({:condition => ["#{@key} like ?", prefix + "%" ]}))
      return entities.map{|entity| entity.__send__(@key)}
    end

    def validate(term, subject)
      found = @klass.find(@options.merge({:condition => ["#{@key} = ?", term]}))
      if found.empty?
	#THINK! Is it a good idea to create missing items in the Argument?
	#Should the Command's action have to do that?
	if(@options[:accept_missing])
	  return true
	elsif(@options[:create_missing])
	  new_attributes = @options[:default_values] || {}
	  new_attributes.merge!( @key => term )
	  @klass.create_with(new_attributes)
	  return true
	else
	  return false
	end
      end
      return true
    end

    def parse(subject, term)
      found = @klass.find(@options.merge({:condition => ["#{@key} = ?", term]}))
      raise RuntimeError, "Couldn't find item on parse!" if found.empty?
      found[0]
    end
  end

  module OgCommands
    class OgModeCommand < Command
      subject_methods :interpreter, :current_state

      doesnt_undo

      action do
	subject.current_state << current
	subject.interpreter.push_mode(my_mode)
      end

      class << self
	def switch_to(model_class, find_by, og_options={})
	  og_options.merge!(:create_missing => true)
	  argument OgArgument.new(:current, model_class, find_by, og_options)

          define_method(:found_current) do
            current.__send__(find_by)
          end
	end

	def mode(command_set)
	  define_method(:my_mode) do
            command_set.set_prompt(/$/, "#{found_current} : ")
	    return command_set
	  end
	end
      end
    end

    class HasOneCommand < Command
      subject_methods :current_state

      action do
        if value.nil?
          dont_undo
          current_value = get_value
          puts get_label(current_value)
        else
          @old_value = get_value
          set_value value
          entity.save
        end
      end

      undo do
        set_value @old_value
        entity.save
      end

      def entity
        subject.current_state.last
      end

      class << self
        def optional_value(target_class, select_by)
          optional_argument OgArgument.new(:value, target_class, select_by)
        end

        def has_one(field)
          define_method(:get_value) do
            entity.__send__(field)
          end

          define_method(:set_value) do |value|
            entity.__send__("#{field}=", value)
          end
        end

        def identified_by(name, &block)
          if block.nil?
            define_method(:get_label) do |value|
              return "" unless value.respond_to?(name.intern)
              value.__send__(name.intern).to_s
            end
          else
            define_method(:get_label) do |value|
              return "" unless value.respond_to?(name.intern)
              block[value.__send__(name.intern)]
            end
          end
        end
      end
    end

    class HasManyListCommand < Command
      optional_argument :search, "A substring of the name of the thing you're looking for"

      doesnt_undo

      subject_methods :current_state

      action do
        options = {}
        unless search.nil?
          options.update({:condition =>
                         ["#{list_attribute} like ?", "%#{search_term}%"]})
        end

        object_list(options).each do |item|
          puts item
        end
      end

      def entity
        subject.current_state.last
      end

      def object_list(options={})
        objects=entity.__send__("find_#{target_name}", options)
        return objects.map do |object|
          object.__send__(list_as)
        end
      end

      class << self
        def has_many(target_name)
          define_method(:target_name) do
            target_name
          end
        end

        def listed_as(list_as)
          define_method(:list_as) do
            list_as
          end
        end
      end
    end

    class HasManyEditCommand < Command
      def add(item)
        owner.__send__("add_#{kind}", item)
      end

      def remove(item)
        owner.__send__("remove_#{kind}", item)
      end

      subject_methods :current_state

      def owner
        subject.current_state.last
      end

      class << self
        def no_more_add_or_remove
          raise NoMethodError,  "Can't add_to and remove_from with same command!"
        end
        private :no_more_add_or_remove

        def defined_sense
          class << self
            alias_method :add_to, :no_more_add_or_remove
            alias_method :remove_from, :no_more_add_or_remove
            def defined_sense
            end
          end
        end

        def find_a(target_class, find_by)
          argument OgArgument.new(:item, target_class, find_by)
        end

        def remove_from(kind)
          define_method(:kind) do
            return kind.to_s.singular
          end

          action do
            remove(item)
          end

          undo do
            add(item)
          end
          defined_sense
        end

        def add_to(kind)
          define_method(:kind) do
            return kind.to_s.singular
          end

          action do
            add(item)
          end

          undo do
            remove(item)
          end
          defined_sense
        end

      end
    end

    class DisplayCommand < Command
      subject_methods :current_state

      doesnt_undo

      action do
        pairs = []
        simple_fields.each_pair do |field, value|
          pairs << [field.to_s, value]
        end
        single_relations.each_pair do |field, value|
          pairs << [field.to_s, value]
        end
        many_relations.each_pair do |field, number|
          pairs << [field.to_s, "#{number} items"]
        end
        field_width = pairs.map{|f,v| f.length}.max + 1
        pairs.each do |field, value|
          puts "#{field.rjust(field_width)}: #{value}"
        end
      end

      def simple_fields
        {}
      end

      def single_relations
        {}
      end

      def many_relations
        {}
      end

      def entity
        subject.current_state.last
      end

      class << self
        def simple_fields(list)
          define_method(:simple_fields) do
            fields = {}
            list.each do |name, field_name|
              fields[name] = entity.__send__(field_name)
            end
            return fields
          end
        end

        def single_relations(list)
          define_method(:single_relations) do
            fields = {}
            list.each do |name, field_name, called|
              target = entity.__send__(field_name)
              if target.nil?
                fields[name] = ""
              else
                fields[name] = target.__send__(called)
              end
            end
            return fields
          end
        end

        def many_relations(list)
          define_method(:many_relations) do
            fields = {}
            list.each do |name, field_name|
              fields[name] = entity.__send__("count_#{field_name}")
            end
            return fields
          end
        end
      end
    end

    class PropertyCommand < Command
      subject_methods :current_state

      action do
        if value.nil?
          dont_undo
          puts get_value
        else
          @old_value = get_value
          set_value value
        end
      end

      undo do
        set_value @old_value
      end

      def entity
        subject.current_state.last
      end

      def value
        nil
      end

      class << self
        def field_name(field)
          define_method(:get_value) do
            entity.__send__(field)
          end

          define_method(:set_value) do |value|
            entity.__send__("#{field}=", value)
          end
        end

        def editable
          optional_argument :value, "The new value"
        end
      end
    end

    class << self
      def command_set(config)
        set = CommandSet.new("og_commands")
        def set.entity_modes
          return @entity_modes||={}
        end
        normalize_config(config)
        entity_commands_from_config(set, config)
        list_command_from_config(set, config)
        return set
      end

      # This is a messy method that ensures that the configuration hash for the
      # CommandSet is well constructed.  It should catch errors and do coversions,
      # set defaults, etc. to set up the creation of the CommandSet.  It's source
      # may be instructive for creating or editing config hashes.
      def normalize_config(config)
        entity_count = 1
        required_names = ["class"]
        config.each do |entity_config|
          required_names.each do |name|
            if entity_config[name].nil?
              raise RuntimeError, "Entity #{entity_config.pretty_inspect} missing #{name}!"
            end
          end

          begin
            real_class = constant(entity_config["class"])
            entity_config["real_class"] = real_class
          rescue NameError
            raise RuntimeError, "Class: #{entity_config["class"]} unrecognized.  Missing require?"
          end

          entity_config["select_by"] = "primary_key" if entity_config["select_by"].nil?

          unless entity_config["edit_command"].nil?
            if entity_config["edit_config"].nil?
              raise RuntimeError, "Class: #{item["class"]} has an edit_command but no edit_config!"
            end
          end

          if entity_config["listable?"]
            if entity_config["list_as"].nil?
              if not entity_config["plural_name"].nil?
                entity_config["list_as"] = entity_config["plural_name"]
              elsif not entity_config["edit_command"].nil?
                entity_config["list_as"] = entity_config["edit_command"] + "s"
              else
                raise RuntimeError, "Class: #{entity_config["class"]} marked listable, " +
                  "but without a list name!"
              end
            end
          end
          entity_count += 1
        end

        #fields pass - so that relations can reuse entity defs
        config.each do |entity_config|
          fields_config = entity_config["edit_config"]
          next if fields_config.nil?

          fields_config["simple_fields"]||=[]
          fields_config["simple_fields"].each do |field_config|
            if field_config["field_name"].nil?
              raise RuntimeError, "Class: #{entity_config["class"]} field missing field_name!"
            end

            field_config["name"]||=field_config["field_name"]
          end

          fields_config["single_relations"]||=[]
          fields_config["single_relations"].each do |relation_config|
            if relation_config["field_name"].nil?
              raise RuntimeError, "Class: #{entity_config["class"]} relation " +
                      "missing field_name!"
            end

            relation_config["name"]||=relation_config["field_name"]
            if relation_config["target"].nil?
              raise RuntimeError, "Class: #{entity_config["class"]} relation " +
                        "#{relation_config["name"]} has no target!"
            end

            relation_config["target"]["select_by"]||="name"
          end

          fields_config["many_relations"]||=[]
          fields_config["many_relations"].each do |relation_config|
            if relation_config["field_name"].nil?
              raise RuntimeError, "Class: #{entity_config["class"]} field missing field_name!"
            end

            relation_config["name"]||=relation_config["field_name"]

            if relation_config["target"].nil?
              raise RuntimeError, "Class: #{entity_config["class"]} relation " +
                          "#{relation_config["name"]} has no target!"
            end

            relation_config["target"]["select_by"]||="name"
            unless Class === relation_config["target"]["real_class"]
              if relation_config["target"]["class"].nil?
                raise RuntimeError,
                              "Class: #{entity_config["class"]} relation " +
                              "#{relation_config["name"]} target has no class!"
              else
                relation_config["target"]["real_class"] =
                  constant(relation_config["target"]["real_class"])
              end
            end
          end
        end
      end


      def entity_commands_from_config(set, config)
        config.each do |entity_config|
          next if entity_config["edit_command"].nil?

          my_mode = entity_mode(entity_config["edit_config"])
          set.entity_modes[entity_config["class"]]=my_mode

          set.command(OgModeCommand, entity_config["edit_command"]) do
            switch_to entity_config["real_class"], entity_config["select_by"]
            mode my_mode
          end
        end
      end

      def list_command_from_config(set, config)
        lists = {}
        config.find_all{|item| item["listable?"] }.each do |item|
          entry = item["list_as"]
          entry_class = item["real_class"]
          find_by = item["select_by"]

          lists[entry] = [entry_class, find_by]
        end

        set.command "list" do
          argument :what, lists.keys

          optional_argument :search, "A substring of the name of the thing you're looking for"

          doesnt_undo

          define_method(:make_list) do |klass, list_attribute, search_term|
            objects = []
            if search_term.nil?
              objects = klass.find
            else
              objects = klass.find(:condition => ["#{list_attribute} like ?",
                                                  "%#{search_term}%"])
            end

            objects.map do |object|
              object.__send__(list_attribute)
            end.each do |item|
              puts item
            end
          end

          action do
            list_me = lists[what]
            raise CommandException if list_me.nil?
            make_list(*(list_me + [search]))
          end
        end
      end


      def entity_mode(fields_config)
        mode = CommandSet.define_commands do
          include_commands StandardCommands::Quit

          command "exit" do
            subject_methods :interpreter, :current_state

            doesnt_undo
            action do
              entity = subject.current_state.pop
              entity.save
              subject.interpreter.pop_mode
            end
          end

          command "delete!" do
            subject_methods :interpreter, :current_state

            action do
              entity = subject.current_state.pop
              entity.delete
              subject.interpreter.pop_mode
            end
          end

          command DisplayCommand, "display" do
            simple_fields fields_config["simple_fields"].map{|f| [f["name"], f["field_name"]]}
            singles = fields_config["single_relations"].map do |f|
              [ f["name"], f["field_name"], f["target"]["select_by"] ]
            end
            single_relations singles
            many_relations fields_config["many_relations"].map{|f| [f["name"], f["field_name"]]}
          end

          fields_config["simple_fields"].each do |property|
            command PropertyCommand, property["name"] do
              field_name property["field_name"]
              if property["edit?"]
                editable
              end
            end
          end

          fields_config["single_relations"].each do |relation|
            command HasOneCommand, relation["name"] do
              optional_value relation["target"]["real_class"], relation["target"]["select_by"]
              has_one relation["field_name"]
              identified_by relation["target"]["select_by"]
            end
          end

          fields_config["many_relations"].each do |relation_config|
            unless relation_config["list?"] or relation_config["edit?"]
              next
            end
            sub_command relation_config["name"] do
              if relation_config["list?"]
                command HasManyListCommand, :list do
                  has_many relation_config["field_name"]
                  listed_as relation_config["target"]["select_by"]
                end
              end

              if relation_config["edit?"]
                command HasManyEditCommand, :add do
                  find_a relation_config["target"]["real_class"],
                    relation_config["target"]["select_by"]
                  add_to relation_config["field_name"]
                end

                command HasManyEditCommand, :remove do
                  find_a relation_config["target"]["real_class"],
                    relation_config["target"]["select_by"]
                  remove_from relation_config["field_name"]
                end
              end
            end
          end
        end
        return mode
      end
    end
  end
end
