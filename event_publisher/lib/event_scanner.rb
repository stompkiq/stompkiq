require 'redis'

class EventScanner

  def initialize(redis=nil)
    @redis = redis ||= Redis.new
  end

  def pull_local_event_from_redis
    @redis.blpop "Stompkiq:LocalEvents"
  end
  
  
  
end
