require 'helper'
require 'stompkiq'
require 'active_record'
require 'action_mailer'
require 'stompkiq/extensions/action_mailer'
require 'stompkiq/extensions/active_record'
require 'stompkiq/rails'

Stompkiq.hook_rails!

class TestExtensions < MiniTest::Unit::TestCase
  describe 'stompkiq extensions' do
    before do
      Stompkiq.redis = REDIS
      Stompkiq.redis {|c| c.flushdb }
    end

    class MyModel < ActiveRecord::Base
      def self.long_class_method
        raise "Should not be called!"
      end
    end

    it 'allows delayed execution of ActiveRecord class methods' do
      assert_equal [], Stompkiq::Client.registered_queues
      assert_equal 0, Stompkiq.redis {|c| c.llen('queue:default') }
      MyModel.delay.long_class_method
      assert_equal ['default'], Stompkiq::Client.registered_queues
      assert_equal 1, Stompkiq.redis {|c| c.llen('queue:default') }
    end

    it 'allows delayed scheduling of AR class methods' do
      assert_equal 0, Stompkiq.redis {|c| c.zcard('schedule') }
      MyModel.delay_for(5.days).long_class_method
      assert_equal 1, Stompkiq.redis {|c| c.zcard('schedule') }
    end

    class UserMailer < ActionMailer::Base
      def greetings(a, b)
        raise "Should not be called!"
      end
    end

    it 'allows delayed delivery of ActionMailer mails' do
      assert_equal [], Stompkiq::Client.registered_queues
      assert_equal 0, Stompkiq.redis {|c| c.llen('queue:default') }
      UserMailer.delay.greetings(1, 2)
      assert_equal ['default'], Stompkiq::Client.registered_queues
      assert_equal 1, Stompkiq.redis {|c| c.llen('queue:default') }
    end

    it 'allows delayed scheduling of AM mails' do
      assert_equal 0, Stompkiq.redis {|c| c.zcard('schedule') }
      UserMailer.delay_for(5.days).greetings(1, 2)
      assert_equal 1, Stompkiq.redis {|c| c.zcard('schedule') }
    end
  end

  describe 'stompkiq rails extensions configuration' do
    before do
      @options = Stompkiq.options
    end

    after do
      Stompkiq.options = @options
    end

    it 'should set enable_rails_extensions option to true by default' do
      assert Stompkiq.options[:enable_rails_extensions]
    end

    it 'should extend ActiveRecord and ActiveMailer if enable_rails_extensions is true' do
      assert Stompkiq.hook_rails!
    end

    it 'should not extend ActiveRecord and ActiveMailer if enable_rails_extensions is false' do
      Stompkiq.options = { :enable_rails_extensions => false }
      refute Stompkiq.hook_rails!
    end
  end
end
