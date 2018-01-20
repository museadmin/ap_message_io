require 'eventmachine'
require 'net/http'
require 'test_helper'
require 'uri'

require_relative '../lib/ap_message_io'
require_relative '../lib/ap_message_io/resources/constants'

# Minitest unit tests for action pack
class ApMessageIoTest < MiniTest::Test
  include Logging
  # Where it all gets written to
  RESULTS_ROOT = "#{Dir.home}/state_machine_root".freeze
  # API SERVER
  BASE_URL = 'http://localhost'
  BASE_PORT = '4567'

  # Teardown the control directories after a test
  TEARDOWN = true
  def teardown
    return unless TEARDOWN && File.directory?(RESULTS_ROOT)
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
    sm.create_action_message('SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('STOPPED', sm, 10)
  end

  # Assert that a payload is picked up from a message file
  # and recorded in the state-machine table
  def test_message_payload
    sm = StateMachine.new
    ApMessageIo.new(state_machine: sm)
    sm.execute

    # Startup, write a shutdown message and wait for exit
    assert(wait_for_run_phase('RUNNING', sm, 10))
    sm.create_action_message('SYS_NORMAL_SHUTDOWN')
    assert(wait_for_run_phase('STOPPED', sm, 10))

    # Assert we set the payload in the state-machine table from the message file
    assert(sm.execute_sql_query(
      'select payload from state_machine' \
      ' where action = \'SYS_NORMAL_SHUTDOWN\';'
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
    sm.create_action_message('SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('STOPPED', sm, 10)

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
    sm.create_action_message('SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('STOPPED', sm, 10)

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
    sm.create_action_message('ACTION_TEST_ACTION')
    assert(wait_for_outbound_message('THIRD_PARTY_ACTION', sm, 10))

    # Then write a shutdown message and wait for exit
    sm.create_action_message('SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('STOPPED', sm, 10)
  end

  # Test the post message endpoint
  def test_post_message
    # Kick off state_machine
    sm = StateMachine.new
    ApMessageIo.new(state_machine: sm)

    # Start the API server and wait for SM to catch up
    sm.start_api_server(log_level: ERROR)
    sm.execute
    wait_for_run_phase('RUNNING', sm, 10)

    # Send shutdown message and wait for state change
    post_to_endpoint(end_point: '/message',
                     body: MSG_TEMPLATE.to_json,
                     header: ACCEPT)
    assert(wait_for_run_phase('STOPPED', sm, 10))
    sm.stop_api_server
  end

  # Test a get against the properties endpoint
  def test_get_properties
    # Kick off state_machine
    sm = StateMachine.new
    ApMessageIo.new(state_machine: sm)

    # Start the API server and wait for SM to catch up
    sm.start_api_server(log_level: ERROR)
    sm.execute
    wait_for_run_phase('RUNNING', sm, 10)

    # Get the properties from the /properties endpoint
    records = get_from_endpoint(end_point: '/properties',
                      body: MSG_TEMPLATE.to_json,
                      header: CONTENT)

    # Assert one of the properties is for the in_pending dir
    assert(records.map { |p| p[0] == 'in_pending' }.include?(true))

    # Then write a shutdown message and wait for exit
    sm.create_action_message('SYS_NORMAL_SHUTDOWN')
    wait_for_run_phase('STOPPED', sm, 10)
    sm.stop_api_server
  end

  # Get from an endpoint
  def get_from_endpoint(args)
    # Create the HTTP objects
    uri = URI.parse(BASE_URL + ':' + BASE_PORT + args[:end_point])
    header = args[:header]
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri, header)

    # Send the request
    response = http.request(request)
    assert(response.kind_of? Net::HTTPSuccess)
    JSON(response.body)
  end

  # Post to an endpoint
  def post_to_endpoint(args)
    # Create the HTTP objects
    uri = URI.parse(BASE_URL + ':' + BASE_PORT + args[:end_point])
    header = args[:header]
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = args[:body]

    # Send the request
    response = http.request(request)
    assert(response.kind_of? Net::HTTPSuccess)
    assert(response.code == 201.to_s)
  end

  # Wait for a change of run phase in the state machine.
  # Raise error if timeout.
  # @param action [String] Action to wait for
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
end