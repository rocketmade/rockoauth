require 'rubygems'
require 'bundler/setup'

require 'active_record'
require 'rockoauth/provider'
RockOAuth::Provider.realm = 'Notes App'

dir = File.expand_path('..', __FILE__)
require dir + '/models/connection'
require dir + '/models/user'
require dir + '/models/note'
