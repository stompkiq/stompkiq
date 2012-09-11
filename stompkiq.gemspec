# -*- encoding: utf-8 -*-
require File.expand_path('../lib/stompkiq/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Chris Meadows, Chris McNabb, Shaun Eutsey, David Brady"]
  gem.date = "2012-09-11"
  gem.email = ["meadoch1@gmail.com", "chrismcnabbsoftwaredeveloper@gmail.com", "shaun@shauneutsey.com", "david.brady@sliderulelabs.com"]
  gem.description   = gem.summary = "Simple, efficient message processing using ActiveMQ Apollo for Ruby"
  gem.homepage      = "https://terenine.github.com/stompkiq"
#  gem.license       = "LGPL-3.0"

  gem.executables   = ['stompkiq', 'stompkiqctl']
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- test/*`.split("\n")
  gem.name          = "stompkiq"
  gem.require_paths = ["lib"]
  gem.version       = Stompkiq::VERSION
  gem.add_dependency                  'redis', '~> 3'
  gem.add_dependency                  'redis-namespace'
  gem.add_dependency                  'connection_pool', '~> 0.9.2'
  gem.add_dependency                  'celluloid', '~> 0.11.1'
  gem.add_dependency                  'multi_json', '~> 1'
  gem.add_development_dependency      'minitest', '~> 3'
  gem.add_dependency                  'stomp', '~> 1.2.4'
#  gem.add_development_dependency      'sinatra'
#  gem.add_development_dependency      'slim'
  gem.add_development_dependency      'rake'
#  gem.add_development_dependency      'actionmailer', '~> 3'
#  gem.add_development_dependency      'activerecord', '~> 3'
end
