require 'test_helper'
require 'ap_message_io/helpers/message_builder'

class ApMessageIoTest < Minitest::Test
  # ACTIONS_DIR = './test/actions'.freeze
  ACTIONS_DIR = './lib/ap_message_io/actions'.freeze

  def test_it_has_a_version_number
    refute_nil ::ApMessageIo::VERSION
  end

  def test_it_loads_user_modules
    sm = StateMachine.new
    sm.include_module('TestModule')
    assert_equal(sm.test_method, 'Test String')
  end

  def test_inbound_message_load
    sm = StateMachine.new
    sm.insert_property(
      'host_file',
      File.absolute_path('./lib/ap_message_io/resources/hosts.json')
    )
    sm.import_action_pack(ACTIONS_DIR)
    Thread.new do
      sm.execute
    end

    to = 10
    while sm.query_run_phase_state != 'RUNNING'
      sleep 1
      raise 'State machine failed to run' if (to -= 1) < 0
    end

    write_message_file(sm.query_property('in_pending'))

    to = 10
    while sm.query_run_phase_state == 'RUNNING'
      sleep 1
      raise 'State machine failed to stop' if (to -= 1) < 0
    end

    assert(Dir[File.join(sm.query_property('in_processed'), '**', '*')]
                .count { |file| File.file?(file) } == 2)
    assert(sm.execute_sql_query('select count(*) id from messages;')[0][0] == 1)
    assert(sm.execute_sql_query('select payload from state_machine' \
      ' where flag = \'SYS_NORMAL_SHUTDOWN\'')[0][0] ==
      '{ "test": "value" }')
  end

  def write_message_file(in_pending)
    builder = MessageBuilder.new
    builder.sender = 'localhost'
    builder.action = 'SYS_NORMAL_SHUTDOWN'
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
