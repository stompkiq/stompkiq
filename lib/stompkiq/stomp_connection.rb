require 'connection_pool'
require 'stomp'

module Stompkiq
  class StompConnection
    def self.create(options={})
      username = options[:username] || ENV['STOMPTOGO_USERNAME'] || 'admin'
      password = options[:password] || ENV['STOMPTOGO_PASSWORD'] || 'password'
      port = (options[:port] || ENV['STOMPTOGO_PORT'] || '61613').to_i
      url = options[:url] || ENV['STOMPTOGO_URL'] || 'localhost'

      # need a connection for Fetcher and Retry
      size = options[:size] || (Stompkiq.server? ? (Stompkiq.options[:concurrency] + 2) : 5)

      ConnectionPool.new(:timeout => 1, :size => size) do
        build_client(username, password, url, port)
      end
    end

    def self.build_client(username, password, url, port)
      Stomp::Client.new(username, password, url, port)
    end
    private_class_method :build_client
  end
end

