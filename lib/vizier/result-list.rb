module Vizier
  module Results
    #The root class of the List class family.  A compositable tree, iterated by ListIterator.
    class ListItem
      class Exception < ::Exception; end
      class NoMatch < Exception; end

      @@next_seq = 0

      def initialize(value)
        @sequence = (@@next_seq +=1)
        @value = value
        @order = nil
        @parent = nil
        @options = {}
        @depth = 0
      end

      attr_reader :value, :sequence
      attr_accessor :parent, :order, :options, :depth

      def ==(other)
        return (ListItem === other &&
                value == other.value)
      end

      def tree_order_next
        right = self.next_sibling
        if right.nil?
          if self.parent.nil?
            return nil
          else
            return self.parent.list_end
          end
        else
          return right
        end
      end

      def to_s
        return @value.to_s
      end

      def eql?(other)
        return self == other
      end

      def next_sibling
        return nil if self.parent.nil?
        return self.parent.after(self)
      end

      def match_on(value)
        return value.to_s == self.to_s
      end

      def match(key)
        if key == :*
          return true
        elsif key == :**
          return true
        else
          match_on(key)
        end
      end

      def filter(path)
        if path.empty? || path == [:**]
          return self
        else
          raise NoMatch
        end
      end

      def inspect
        "<i(#{@order}) #{value.inspect}>"
      end
    end

    #A sort of virtual list element, used to denote the end of a list in iteration.
    class ListEnd < ListItem
      def initialize(end_of)
        @end_of = end_of
      end

      attr_reader :end_of

      def parent
        @end_of.parent
      end

      def order
        @end_of.order
      end

      def next_sibling
        @end_of.next_sibling
      end

      def to_s
        @end_of.to_s
      end

      def inspect
        "<e(#{@end_of.order}):#{@end_of.name}>"
      end
    end

    #A List contains ListItems - this class is sorely under-documented.
    #Honestly, much of it's functionality is either speculative (and it's quite
    #possible that you ain't gonna need it) or else required by internal
    #code and probably not needed by client code.
    #
    #What's most important to understand is that Lists can nest both
    #ListItems and other Lists, which makes them a bit like a tree, and a
    #bit like a list.
    class List < ListItem
      def initialize(name, values=[])
        @name = name
        create_order = 0
        values = values.map do |item|
          if ListItem === item
            if item.order.nil?
              item.order = (create_order += 1)
            else
              create_order = item.order
            end
          else
            item = ListItem.new(item)
            item.order = (create_order += 1)
          end

          if item.parent.nil?
            item.parent = self
          end

          item
        end
        super(values)
        @open = true
      end

      attr_reader :name
      alias values value

      def to_s
        @name.to_s
      end

      def list_end
        return ListEnd.new(self)
      end

      def tree_order_next
        deeper = self.first_child
        if deeper.nil?
          return self.list_end
        else
          return deeper
        end
      end

      #Helper for #filter
      def filter_into_array(path)
        next_path = path.first == :** ? path : path[1..-1]
        return values.find_all do |value|
          value.match(path[0])
        end.map do |item|
          begin
            item.filter(next_path)
          rescue NoMatch => nm
            nm
          end
        end.reject do |value|
          NoMatch === value
        end
      end

      #+path+ should be an array of arguments to match (against list names
      #or item values).  The special path element +:**+ can be used to keep
      #opening lists to find whatever.  The result will be a List that
      #contains only matching elements. +:*+ will match any single item at
      #that level.
      def filter(path)
        if path == [:**]
          list = List.new(@name, @value)
          list.order = @order
          return list
        end

        if path.first == :**
          double_stars = filter_into_array(path)
          path = path[1..-1]
        else
          double_stars = nil
        end

        list = filter_into_array(path)

        if (double_stars.nil? || double_stars.empty?) && path.length > 0 && list.empty?
          raise NoMatch
        end

        unless double_stars.nil?
          list.each do |item|
            unless double_stars.find {|starred| starred.order == item.order }
              double_stars << item
            end
          end

          double_stars.sort! {|left, right| left.order <=> right.order}

          list = double_stars
        end

        list = List.new(@name, list)
        list.order = @order
        return list
      end

      def open?
        @open
      end

      def first_child
        if values.empty?
          return nil
        else
          return values[0]
        end
      end

      def after(item)
        index = nil
        values.each_with_index do |value, idx|
          if value.equal?(item)
            index = idx
            break
          end
        end
        if index.nil? or index >= values.length
          return nil
        else
          return values[index + 1]
        end
      end

      def close
        return self unless @open
        @open = false
        values.each do |item|
          next unless List === item
          item.close
        end
        return self
      end

      def add(item)
        unless ListItem === item
          item = ListItem.new(item)
        end
        item.parent = self
        item.order = values.length
        values.push(item)
        return item
      end

      def ==(other)
        return (List === other &&
                name == other.name &&
                values == other.values)
      end

      def eql?(other)
        return self == other
      end

      def inspect
        "<#{@open ? "L":"l"}(#@order):#{name.to_s} #{values.inspect} #{name.to_s}>"
      end
    end

    #Basically an Enumerator over a List.  Give it any list element, and
    ##each will take you to the end of the list.
    class ListIterator
      include Enumerable
      def initialize(list)
        @list = list
      end

      def each
        thumb = @list
        until thumb.nil?
          yield thumb
          thumb = thumb.tree_order_next
        end
      end
    end
  end
end
