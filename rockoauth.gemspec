spec = Gem::Specification.new do |s|
  s.name              = 'rockoauth'
  s.version           = '0.1.1'
  s.summary           = 'Simple OAuth 2.0 provider toolkit'
  s.authors           = ['Daniel Evans', 'James Coglan']
  s.email             = 'evans.daniel.n@gmail.com'
  s.homepage          = 'http://github.com/rocketmade/rockoauth'

  s.extra_rdoc_files  = %w[README.md]
  s.rdoc_options      = %w[--main README.md]

  s.files             = %w[History.txt README.md] + Dir.glob('{example,lib,spec}/**/*.{css,erb,rb,rdoc,ru,md}')
  s.require_paths     = ['lib']

  s.add_dependency 'activerecord', ">= 4.0"
  s.add_dependency 'bcrypt-ruby'
  s.add_dependency 'json'
  s.add_dependency 'rack'

  s.add_development_dependency 'appraisal', '~> 1.0.0'
  s.add_development_dependency 'mysql', '~> 2.9.0' if ENV['DB'] == 'mysql' # version locked by ActiveRecord
  s.add_development_dependency 'pg' if ENV['DB'] == 'postgres'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'sinatra', '>= 1.3.0'
  s.add_development_dependency 'thin'
  s.add_development_dependency 'factory_girl', '~> 2.0'
end
