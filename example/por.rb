require 'stompkiq'

# If your client is single-threaded, we just need a single connection in our Redis connection pool
#Stompkiq.configure_client do |config|
#  config.redis = { :namespace => 'x', :size => 1, :url => 'redis://redis.host:1234/14' }
#end

# Stompkiq server is multi-threaded so our Redis connection pool size defaults to concurrency (-c)
#Stompkiq.configure_server do |config|
#  config.redis = { :namespace => 'x', :url => 'redis://redis.host:1234/14' }
#end

# Start up stompkiq via
# ./bin/stompkiq -r ./examples/por.rb
# and then you can open up an IRB session like so:
# irb -r ./examples/por.rb
# where you can then say
# PlainOldRuby.perform_async "like a dog", 3
#
class PlainOldRuby
  include Stompkiq::Worker

  def perform(how_hard="super hard", how_long=1)
    sleep how_long
    puts "Workin' #{how_hard}"
  end

  def self.run_many(how_many=5, min_time=0, max_time=5)
    1.upto(how_many) do |n|
      t = (min_time..max_time).to_a.sample
      perform_async "Worker #{n}, worked #{t} secs", t
    end
  end
  
end
