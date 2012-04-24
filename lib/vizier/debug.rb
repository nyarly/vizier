module Vizier
  module Debug
    def self.debug_to(target)
      define_method :debug do |object|
        PP.pp object, target
      end
    end

    def debug(*args)
    end
  end
end

#Vizier::Debug::debug_to($stdout)
