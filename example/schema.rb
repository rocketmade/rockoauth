require 'rubygems'
require 'bundler/setup'

require 'rockoauth/provider'
require 'active_record'
require File.expand_path('../models/connection', __FILE__)

ActiveRecord::Schema.define do |version|
  create_table :users, :force => true do |t|
    t.timestamps
    t.string :username
  end

  create_table :notes, :force => true do |t|
    t.timestamps
    t.belongs_to :user
    t.string     :title
    t.text       :body
  end
end

RockOAuth::Model::Schema.up
