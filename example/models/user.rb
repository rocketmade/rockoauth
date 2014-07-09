class User < ActiveRecord::Base
  include RockOAuth::Model::ResourceOwner
  include RockOAuth::Model::ClientOwner
  has_many :notes
end
