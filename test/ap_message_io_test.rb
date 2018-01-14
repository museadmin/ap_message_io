require 'test_helper'
require 'ap_message_io/helpers/message_builder'
require 'eventmachine'

# Minitest unit tests for action pack
class ApMessageIoTest < MiniTest::Test
  # Where it all gets written to
  RESULTS_ROOT = "#{Dir.home}/state_machine_root".freeze

  # Disable this if debugging a failure...
  def teardown
    return unless File.directory?(RESULTS_ROOT)
    FileUtils.rm_rf("#{RESULTS_ROOT}/.", secure: true)
  end

  # Test we remembered to include a gem version
  def test_it_has_a_version_number
    refute_nil ::ApMessageIo::VERSION
  end

  # Confirm that SM can load one of our modules
  def test_it_loads_user_modules
    sm = StateMachine.new
    sm.include_module('ApMessageIoModule')
    assert_equal(sm.test_method, 'Test String')
  end

  # Load our actions and then drop in a message
  # for the SYS_NORMAL_SHUTDOWN action. Fail if we timeout
  # waiting for shutdown.
  def test_message_execution
    sm = StateMachine.new
    ApMessageIo.new(state_machine: sm)
    sm.execute

    # Startup, write a shutdown message and wait for exit
    wait_for_run_phase('RUNNING', sm, 10)
    write_message_file(sm.in_pending_dir, 'SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('SHUTDOWN', sm, 10)
  end

  # Assert that a payload is picked up from a message file
  # and recorded in the state-machine table
  def test_message_payload
    sm = StateMachine.new
    ApMessageIo.new(state_machine: sm)
    sm.execute

    # Startup, write a shutdown message and wait for exit
    assert(wait_for_run_phase('RUNNING', sm, 10))
    write_message_file(sm.in_pending_dir, 'SYS_NORMAL_SHUTDOWN')
    assert(wait_for_run_phase('SHUTDOWN', sm, 10))

    # Assert we set the payload in the state-machine table from the message file
    assert(sm.execute_sql_query(
      'select payload from state_machine' \
      ' where flag = \'SYS_NORMAL_SHUTDOWN\';'
    )[0][0] == '{ "test": "value" }')

    # Assert the payload is written into the messages table
    assert(sm.execute_sql_query(
      'select payload from messages ' \
      'where action = \'SYS_NORMAL_SHUTDOWN\';'
    )[0][0] == '{ "test": "value" }')
  end

  # Assert inbound messages are recorded in db
  def test_messaging_table
    sm = StateMachine.new
    ApMessageIo.new(state_machine: sm)
    sm.execute

    # Startup, write a shutdown message and wait for exit
    wait_for_run_phase('RUNNING', sm, 10)
    write_message_file(sm.in_pending_dir, 'SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('SHUTDOWN', sm, 10)

    # Assert we have one received message in the dB messages table
    # and an ack
    assert(sm.execute_sql_query(
      'select count(*) id from messages;'
    )[0][0] == 2)
  end

  # Assert the message files are moved to processed and
  # that the expected number are found
  def test_message_file_handling
    sm = StateMachine.new
    ApMessageIo.new(state_machine: sm)
    sm.include_module('ApMessageIoModule')
    sm.execute

    # Startup, write a shutdown message and wait for exit
    wait_for_run_phase('RUNNING', sm, 10)
    write_message_file(sm.in_pending_dir, 'SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('SHUTDOWN', sm, 10)

    # Assert message files were move to processed
    assert(Dir[File.join(sm.in_processed_dir, '**', '*')]
               .count { |file| File.file?(file) } == 2)

    # Assert ack file is present in outbound dir
    assert(Dir[File.join(sm.out_pending_dir, '**', '*')]
               .count { |file| File.file?(file) } == 2)
  end

  # Test that an outbound message is found in db
  # and written out to file in outbound dir
  def test_process_outbound_message
    sm = StateMachine.new
    sm.include_module('ApMessageIoModule')
    ap = ApMessageIo.new(state_machine: sm)

    # Export our unit test actions to the state machine and begin
    # executing
    ap.export_action_pack(state_machine: sm, dir: 'test/actions')
    sm.execute
    wait_for_run_phase('RUNNING', sm, 10)

    # Trigger a test action that writes an out bound msg
    write_message_file(sm.in_pending_dir, 'ACTION_TEST_ACTION')
    assert(wait_for_outbound_message('THIRD_PARTY_ACTION', sm, 10))
    # Then write a shutdown message and wait for exit
    write_message_file(sm.in_pending_dir, 'SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('SHUTDOWN', sm, 10)
  end

  # Test the Api Server
  def test_webrick_api_server
    sm = StateMachine.new
    ApMessageIo.new(state_machine: sm)
    sm.execute
    # TODO Api can now ref sm so add some useful endpoints and tests
    # inbound msg
    # query of properties
    sm.start_api_server
    sleep(5)
    sm.stop_api_server
    # Then write a shutdown message and wait for exit
    write_message_file(sm.in_pending_dir, 'SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('SHUTDOWN', sm, 10)
  end

  # Wait for a change of run phase in the state machine.
  # Raise error if timeout.
  # @param action [String] Action flag to wait for
  # @param time_out [FixedNum] The time out period
  def wait_for_outbound_message(action, sm, time_out)
    EM.run do
      EM::Timer.new(time_out) do
        EM.stop
        return false
      end

      EM::PeriodicTimer.new(1) do
        Dir["#{sm.out_pending_dir}/*"].each do |file|
          if File
             .foreach(file)
             .grep(/#{action}/)
             .any?
            EM.stop
            return true
          end
        end
      end
    end
  end

  # Wait for a change of run phase in the state machine.
  # Raise error if timeout.
  # @param phase [String] Name of phase to wait for
  # @param state_machine [StateMachine] An instance of a state machine
  # @param time_out [FixedNum] The time out period
  def wait_for_run_phase(phase, state_machine, time_out)
    EM.run do
      EM::Timer.new(time_out) do
        EM.stop
        return false
      end

      EM::PeriodicTimer.new(1) do
        if state_machine.query_run_phase_state == phase
          EM.stop
          return true
        end
      end
    end
  end

  # Drop a message into the queue with an action flag
  def write_message_file(in_pending, flag)
    js = build_message(flag)
    name = JSON.parse(js)['id']
    File.open("#{in_pending}/#{name}", 'w') { |f| f.write(js) }
    File.open("#{in_pending}/#{name}.flag", 'w') { |f| f.write('') }
  end

  # Build a test message
  def build_message(flag)
    builder = MessageBuilder.new
    builder.sender = 'localhost'
    builder.action = flag
    builder.payload = '{ "test": "value" }'
    builder.direction = 'in'
    builder.build
  end
end