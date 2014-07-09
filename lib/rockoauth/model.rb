require 'active_record'

module RockOAuth
  module Model
    autoload :Helpers,       ROOT + '/model/helpers'
    autoload :ClientOwner,   ROOT + '/model/client_owner'
    autoload :ResourceOwner, ROOT + '/model/resource_owner'
    autoload :Hashing,       ROOT + '/model/hashing'
    autoload :Authorization, ROOT + '/model/authorization'
    autoload :Client,        ROOT + '/model/client'

    Schema = RockOAuth::Schema

    DUPLICATE_RECORD_ERRORS = [
                               /^Mysql::Error:\s+Duplicate\s+entry\b/,
                               /^PG::Error:\s+ERROR:\s+duplicate\s+key\b/,
                               /\bConstraintException\b/
                              ]

    # ActiveRecord::RecordNotUnique was introduced in Rails 3.0 so referring
    # to it while running earlier versions will raise an error. The above
    # error strings should match PostgreSQL, MySQL and SQLite errors on
    # Rails 2. If you're running a different adapter, add a suitable regex to
    # the list:
    #
    #     RockOAuth::Model::DUPLICATE_RECORD_ERRORS << /DB2 found a dup/
    #
    def self.duplicate_record_error?(error)
      error.class.name == 'ActiveRecord::RecordNotUnique' or
        DUPLICATE_RECORD_ERRORS.any? { |re| re =~ error.message }
    end

    def self.find_access_token(access_token)
      return nil if access_token.nil?
      Authorization.find_by_access_token_hash(RockOAuth.hashify(access_token))
    end
  end
end
