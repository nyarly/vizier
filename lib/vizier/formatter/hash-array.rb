require 'vizier/results'

module Vizier::Results
  class HashArrayFormatter < Formatter
    def initialize
      @hash_stack = [{:array => []}]
      super
    end

    def hash
      @hash_stack.last
    end

    def array
      hash[:array]
    end

    def closed_begin_list(list)
      list_array = []
      list_hash = {:array => list_array}
      array.push(list_array)
      hash[array().length.to_s] = list_hash
      hash[list.name] = list_hash
      @hash_stack.push(list_hash)
    end

    def closed_item(item)
      thing = item.value
      array().push(thing)
      hash()[array().length.to_s] = thing
    end

    def closed_end_list(list)
      @hash_stack.pop
    end

    def structure
      @hash_stack.first
    end
  end
end
