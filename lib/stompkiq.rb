# require 'stompkiq/version'
require 'stompkiq/logging'
# require 'stompkiq/client'
# require 'stompkiq/worker'
# require 'stompkiq/redis_connection'
# require 'stompkiq/util'

# require 'stompkiq/extensions/action_mailer'
# require 'stompkiq/extensions/active_record'
# require 'stompkiq/rails' if defined?(::Rails::Engine)

require 'multi_json'

module Stompkiq

  DEFAULTS = {
    :queues => [],
    :concurrency => 25,
    :require => '.',
    :environment => nil,
    :timeout => 8,
    :enable_rails_extensions => true,
  }

  def self.options
    @options ||= DEFAULTS.dup
  end

  def self.options=(opts)
    @options = opts
  end

  ##
  # Configuration for Stompkiq server, use like:
  #
  #   Stompkiq.configure_server do |config|
  #     config.redis = { :namespace => 'myapp', :size => 25, :url => 'redis://myhost:8877/mydb' }
  #     config.server_middleware do |chain|
  #       chain.add MyServerHook
  #     end
  #   end
  def self.configure_server
    yield self if server?
  end

  ##
  # Configuration for Stompkiq client, use like:
  #
  #   Stompkiq.configure_client do |config|
  #     config.redis = { :namespace => 'myapp', :size => 1, :url => 'redis://myhost:8877/mydb' }
  #   end
  def self.configure_client
    yield self unless server?
  end

  def self.server?
    defined?(Stompkiq::CLI)
  end

  def self.redis(&block)
    @redis ||= Stompkiq::RedisConnection.create
    raise ArgumentError, "requires a block" unless block_given?
    @redis.with(&block)
  end

  def self.redis=(hash)
    if hash.is_a?(Hash)
      @redis = RedisConnection.create(hash)
    elsif hash.is_a?(ConnectionPool)
      @redis = hash
    else
      raise ArgumentError, "redis= requires a Hash or ConnectionPool"
    end
  end

  def self.stomp(&block)
    @stomp ||= Stompkiq::StompConnection.create
    raise ArgumentError, "requires a block" unless block_given?
    @stomp.with(&block)
  end

  def self.stomp=(hash)
    if hash.is_a?(Hash)
      @stomp = StompConnection.create(hash)
    elsif hash.is_a?(ConnectionPool)
      @stomp = hash
    else
      raise ArgumentError, "stomp= requires a Hash or ConnectionPool"
    end
  end

  def self.client_middleware
    @client_chain ||= Client.default_middleware
    yield @client_chain if block_given?
    @client_chain
  end

  def self.server_middleware
    @server_chain ||= Processor.default_middleware
    yield @server_chain if block_given?
    @server_chain
  end

  def self.load_json(string)
    MultiJson.decode(string)
  end

  def self.dump_json(object)
    MultiJson.encode(object)
  end

  def self.logger
    Stompkiq::Logging.logger
  end

  def self.logger=(log)
    Stompkiq::Logging.logger = log
  end

  def self.poll_interval=(interval)
    self.options[:poll_interval] = interval
  end

end
