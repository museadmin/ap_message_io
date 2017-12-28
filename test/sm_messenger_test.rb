require 'test_helper'
require './lib/sm_messenger/helpers/message_builder'

class SmMessengerTest < Minitest::Test
  # ACTIONS_DIR = './test/actions'.freeze
  ACTIONS_DIR = './lib/sm_messenger/actions'.freeze

  def test_it_has_a_version_number
    refute_nil ::SmMessenger::VERSION
  end

  def test_it_loads_user_modules
    sm = StateMachine.new(user_actions_dir: ACTIONS_DIR)
    sm.include_module('TestModule')
    assert_equal(sm.test_method, 'Test String')
  end

  def test_inbound_message_load
    sm = StateMachine.new(user_actions_dir: ACTIONS_DIR)
    sm.insert_property(
        'host_file',
        File.absolute_path('./lib/sm_messenger/resources/hosts.json')
    )
    sm.load_actions
    Thread.new do
      sm.execute
    end

    to = 10
    while sm.query_run_phase_state != 'RUNNING' do
      sleep 1
      raise 'State machine failed to run' if (to -= 1) < 0
    end

    write_message_file(sm.query_property('in_pending'))

    to = 10
    while sm.query_run_phase_state == 'RUNNING' do
      sleep 1
      raise 'State machine failed to stop' if (to -= 1) < 0
    end

    assert(Dir[File.join(sm.query_property('in_processed'), '**', '*')]
                .count { |file| File.file?(file) } == 2)
    assert(sm.execute_sql_query('select count(*) id from messages;')[0][0] == 1)
  end

  def write_message_file(in_pending)
    builder = MessageBuilder.new
    builder.sender = 'localhost'
    builder.action = 'SHUTDOWN'
    builder.payload = '{ "test": "value" }'
    js = builder.build

    File.open("#{in_pending}/#{builder.id}", 'w') do |f|
      f.write(js)
    end

    File.open("#{in_pending}/#{builder.id}.flag", 'w') do |f|
      f.write('')
    end
  end
end
