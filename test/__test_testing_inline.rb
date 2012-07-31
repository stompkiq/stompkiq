require 'helper'
require 'stompkiq'
require 'stompkiq/worker'
require 'active_record'
require 'action_mailer'
require 'stompkiq/rails'
require 'stompkiq/extensions/action_mailer'
require 'stompkiq/extensions/active_record'

Stompkiq.hook_rails!

class TestInline < MiniTest::Unit::TestCase
  describe 'stompkiq inline testing' do
    class InlineError < RuntimeError; end
    class ParameterIsNotString < RuntimeError; end

    class InlineWorker
      include Stompkiq::Worker
      def perform(pass)
        raise InlineError unless pass
      end
    end

    class InlineWorkerWithTimeParam
      include Stompkiq::Worker
      def perform(time)
        raise ParameterIsNotString unless time.is_a?(String)
      end
    end

    class InlineFooMailer < ActionMailer::Base
      def bar(str)
        raise InlineError
      end
    end

    class InlineFooModel < ActiveRecord::Base
      def self.bar(str)
        raise InlineError
      end
    end

    before do
      load 'stompkiq/testing/inline.rb'
    end

    after do
      Stompkiq::Worker::ClassMethods.class_eval do
        remove_method :perform_async
        alias_method :perform_async, :perform_async_old
        remove_method :perform_async_old
      end
    end

    it 'stubs the async call when in testing mode' do
      assert InlineWorker.perform_async(true)

      assert_raises InlineError do
        InlineWorker.perform_async(false)
      end
    end

    it 'stubs the delay call on mailers' do
      assert_raises InlineError do
        InlineFooMailer.delay.bar('three')
      end
    end

    it 'stubs the delay call on models' do
      assert_raises InlineError do
        InlineFooModel.delay.bar('three')
      end
    end

    it 'stubs the enqueue call when in testing mode' do
      assert Stompkiq::Client.enqueue(InlineWorker, true)

      assert_raises InlineError do
        Stompkiq::Client.enqueue(InlineWorker, false)
      end
    end

    it 'should relay parameters through json' do
      assert Stompkiq::Client.enqueue(InlineWorkerWithTimeParam, Time.now)
    end
  end
end
