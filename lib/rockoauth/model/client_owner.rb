module RockOAuth
  module Model

    module ClientOwner
      def self.included(klass)
        klass.has_many :oauth2_clients,
        :class_name => 'RockOAuth::Model::Client',
        :as => :oauth2_client_owner
      end
    end

  end
end
