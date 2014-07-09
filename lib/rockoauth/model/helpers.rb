module RockOAuth
  module Model

    module Helpers
      def self.count(model, conditions={})
        if model.respond_to?(:where)
          model.where(conditions).count
        else
          model.count(:conditions => conditions)
        end
      end
    end
  end
end
