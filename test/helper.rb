ENV['RACK_ENV'] = ENV['RAILS_ENV'] = 'test'
if ENV.has_key?("SIMPLECOV")
  require 'simplecov'
  SimpleCov.start
end

require 'minitest/unit'
require 'minitest/pride'
require 'minitest/autorun'

require 'celluloid'

require 'apollo_mgmt'
APOLLO_BROKER = ApolloMgmt::Broker.new

require 'stompkiq'
require 'stompkiq/util'
Stompkiq.logger.level = Logger::ERROR

require 'stompkiq/redis_connection'
REDIS = Stompkiq::RedisConnection.create(:url => "redis://localhost/15", :namespace => 'testy')

require 'stompkiq/stomp_connection'
STOMP = Stompkiq::StompConnection.create

