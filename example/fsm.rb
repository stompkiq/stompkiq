require 'stompkiq'
# require 'state_machine'
require 'redis'
require 'multi_json'

# Start up stompkiq via
# ./bin/stompkiq -r ./example/fsm.rb
# and then you can open up an IRB session like so:
# irb -r ./example/fsm.rb
# where you can then say
# job = Job.new 1
# job.name = 'snoopy'
# job.do_work
#

class StepOne
  include Stompkiq::Worker

  def perform(job_id)
    redis = Redis.new
    job = Job.new job_id, redis
    stats = {threadid: Thread.current.object_id.to_s(36), step_no: 1, start: Time.now.to_s}
    puts "Job #{job_id} in StepOne"
    sleep 2
    stats[:end] =  Time.now.to_s
    job.process_steps << stats
    job.do_more_work redis
  end
end

class StepTwo
  include Stompkiq::Worker

  def perform(job_id)
    redis = Redis.new
    job = Job.new job_id, redis
    stats = {threadid: Thread.current.object_id.to_s(36), step_no: 2, start: Time.now.to_s}
    puts "Job #{job_id} in StepTwo"
    sleep 2
    stats[:end] =  Time.now.to_s
    job.process_steps << stats
    job.persist_to redis
  end
end

class StepThree
  include Stompkiq::Worker

  def perform(job_id)
    redis = Redis.new
    job = Job.new job_id, redis
    stats = {threadid: Thread.current.object_id.to_s(36), step_no: 3, start: Time.now.to_s}
    puts "Job #{job_id} in StepThree"
    sleep 2
    stats[:end] =  Time.now.to_s
    job.process_steps << stats
    job.persist_to redis
  end
end

class Job
  attr_accessor :job_id, :name, :process_steps
  
  def initialize(job_id, redis=nil)
    @job_id = job_id
    @process_steps = []
    hydrate_from redis if redis
  end

  def hydrate_from(redis)
    state = MultiJson.load redis.get("JobObject:#{job_id}"), symbolize_keys: true
    @name = state[:name]
    @process_steps = []
    redis.hgetall("JobObject:#{job_id}:steps").each do |step_no, stat|
      @process_steps << MultiJson.load(stat, symbolize_keys: true)
    end
  end

  def persist_to(redis)
    state = { job_id: job_id, name: name}
    redis.set "JobObject:#{job_id}", MultiJson.dump(state)
    @process_steps.each do |step|
      redis.hset "JobObject:#{job_id}:steps", step[:step_no], MultiJson.dump(step)
    end
    
  end

  def do_work
    redis = Redis.new
    persist_to redis
    StepOne.perform_async job_id
  end

  def do_more_work(redis)
    persist_to redis
    StepTwo.perform_async job_id
    StepThree.perform_async job_id
  end
  
    
  
end

  
