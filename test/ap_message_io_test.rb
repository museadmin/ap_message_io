require 'test_helper'
require 'ap_message_io/helpers/message_builder'

require 'eventmachine'

# Minitest unit tests for action pack
class ApMessageIoTest < Minitest::Test
  # Relative path to our actions
  ACTIONS_DIR = './lib/ap_message_io/actions'.freeze

  # Test we remembered to include a gem version
  def test_it_has_a_version_number
    refute_nil ::ApMessageIo::VERSION
  end

  # Confirm that SM can load one of our modules
  def test_it_loads_user_modules
    sm = StateMachine.new
    sm.include_module('TestModule')
    assert_equal(sm.test_method, 'Test String')
  end

  # Load our actions and then drop in a message
  # for the SYS_NORMAL_SHUTDOWN action. Fail if we timeout
  # waiting for shutdown.
  def test_message_execution
    sm = StateMachine.new
    ap = ApMessageIo.new

    # Export our actions to the state machine
    ap.export_action_pack(sm)
    Thread.new do
      sm.execute
    end

    # Startup, write a shutdown message and wait for exit
    wait_for_run_phase('RUNNING', sm, 10)
    write_message_file(sm.query_property('in_pending'))
    wait_for_run_phase('SHUTDOWN', sm, 10)
  end

  def test_message_payload
    sm = StateMachine.new
    ap = ApMessageIo.new

    # Export our actions to the state machine
    ap.export_action_pack(sm)
    Thread.new do
      sm.execute
    end

    # Startup, write a shutdown message and wait for exit
    assert(wait_for_run_phase('RUNNING', sm, 10))
    write_message_file(sm.query_property('in_pending'))
    assert(wait_for_run_phase('SHUTDOWN', sm, 10))

    # Assert we set the unused payload from the message file
    assert(sm.execute_sql_query('select payload from state_machine' \
      ' where flag = \'SYS_NORMAL_SHUTDOWN\'')[0][0] ==
               '{ "test": "value" }')
  end

  def test_messaging_table
    sm = StateMachine.new
    ap = ApMessageIo.new

    # Export our actions to the state machine
    ap.export_action_pack(sm)
    Thread.new do
      sm.execute
    end

    # Startup, write a shutdown message and wait for exit
    wait_for_run_phase('RUNNING', sm, 10)
    write_message_file(sm.query_property('in_pending'))
    wait_for_run_phase('SHUTDOWN', sm, 10)

    # Assert we have one received message in the dB messages table
    # and an ack
    assert(sm.execute_sql_query(
        'select count(*) id from messages;')[0][0] == 2
    )
  end

  def test_message_file_handling
    sm = StateMachine.new
    ap = ApMessageIo.new

    # Export our actions to the state machine
    ap.export_action_pack(sm)
    Thread.new do
      sm.execute
    end

    # Startup, write a shutdown message and wait for exit
    wait_for_run_phase('RUNNING', sm, 10)
    write_message_file(sm.query_property('in_pending'))
    wait_for_run_phase('SHUTDOWN', sm, 10)

    # Assert message files were move to processed
    assert(Dir[File.join(sm.query_property('in_processed'), '**', '*')]
               .count { |file| File.file?(file) } == 2)

    # Assert ack file is present in outbound dir
    assert(Dir[File.join(sm.query_property('out_pending'), '**', '*')]
               .count { |file| File.file?(file) } == 2)
  end

  # Wait for a change of run phase in the state machine.
  # Raise error if timeout.
  # @param phase [String] Name of phase to wait for
  # @param state_machine [StateMachine] An instance of a state machine
  # @param time_out [FixedNum] The time out period
  def wait_for_run_phase(phase, state_machine, time_out)
    EM.run do
      t = EM::Timer.new(time_out) do
        return false
      end

      p = EM::PeriodicTimer.new(1) do
        if state_machine.query_run_phase_state == phase
          p.cancel
          t.cancel
          EM.stop
          return true
        end
      end
    end
  end

  # Drop a message into the queue with a shutdown flag
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
