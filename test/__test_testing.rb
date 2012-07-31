require 'helper'
require 'stompkiq'
require 'stompkiq/worker'
require 'active_record'
require 'action_mailer'
require 'stompkiq/rails'
require 'stompkiq/extensions/action_mailer'
require 'stompkiq/extensions/active_record'

Stompkiq.hook_rails!

class TestTesting < MiniTest::Unit::TestCase
  describe 'stompkiq testing' do
    class PerformError < RuntimeError; end

    class DirectWorker
      include Stompkiq::Worker
      def perform(a, b)
        a + b
      end
    end

    class EnqueuedWorker
      include Stompkiq::Worker
      def perform(a, b)
        a + b
      end
    end

    class StoredWorker
      include Stompkiq::Worker
      def perform(error)
        raise PerformError if error
      end
    end

    class FooMailer < ActionMailer::Base
      def bar(str)
        str
      end
    end

    class FooModel < ActiveRecord::Base
      def bar(str)
        str
      end
    end

    before do
      load 'stompkiq/testing.rb'
    end

    after do
      # Undo override
      Stompkiq::Worker::ClassMethods.class_eval do
        remove_method :client_push
        alias_method :client_push, :client_push_old
        remove_method :client_push_old
      end
    end

    it 'stubs the async call' do
      assert_equal 0, DirectWorker.jobs.size
      assert DirectWorker.perform_async(1, 2)
      assert_equal 1, DirectWorker.jobs.size
      assert DirectWorker.perform_in(10, 1, 2)
      assert_equal 2, DirectWorker.jobs.size
      assert DirectWorker.perform_at(10, 1, 2)
      assert_equal 3, DirectWorker.jobs.size
      assert_in_delta 10.seconds.from_now.to_f, DirectWorker.jobs.last['at'], 0.01
    end

    it 'stubs the delay call on mailers' do
      assert_equal 0, Stompkiq::Extensions::DelayedMailer.jobs.size
      FooMailer.delay.bar('hello!')
      assert_equal 1, Stompkiq::Extensions::DelayedMailer.jobs.size
    end

    it 'stubs the delay call on models' do
      assert_equal 0, Stompkiq::Extensions::DelayedModel.jobs.size
      FooModel.delay.bar('hello!')
      assert_equal 1, Stompkiq::Extensions::DelayedModel.jobs.size
    end

    it 'stubs the enqueue call' do
      assert_equal 0, EnqueuedWorker.jobs.size
      assert Stompkiq::Client.enqueue(EnqueuedWorker, 1, 2)
      assert_equal 1, EnqueuedWorker.jobs.size
    end

    it 'executes all stored jobs' do
      assert StoredWorker.perform_async(false)
      assert StoredWorker.perform_async(true)

      assert_equal 2, StoredWorker.jobs.size
      assert_raises PerformError do
        StoredWorker.drain
      end
      assert_equal 0, StoredWorker.jobs.size
    end
  end
end
