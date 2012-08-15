require 'sinatra/base'
require 'redis'

module EventSource
  class EventStatsApp < Sinatra::Base
    
    get '/stats/:klass' do
      @redis = Redis.new
      @redis.hget "EventStats", params[:klass]
    end

    get '/stats' do
      @redis = Redis.new
      @stats = @redis.hgetall "EventStats"
      puts @stats
      erb :stats
    end
    
    run! if __FILE__ == $0
  end
end

