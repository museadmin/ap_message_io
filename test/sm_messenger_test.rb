require 'test_helper'

class SmMessengerTest < Minitest::Test
  # ACTIONS_DIR = './test/actions'.freeze
  ACTIONS_DIR = './lib/sm_messenger/actions'.freeze

  def test_that_messenger_has_a_version_number
    refute_nil ::SmMessenger::VERSION
  end

  def test_state_machine_loads_user_actions
    sm = StateMachine.new(user_actions_dir: ACTIONS_DIR)
    sm.load_actions
    sm.execute
  end

  def test_state_machine_loads_user_modules
    sm = StateMachine.new(user_actions_dir: ACTIONS_DIR)
    sm.include_module('TestModule')
    assert_equal(sm.test_method, 'Test String')
  end

  def test_load_of_hosts_file
    sm = StateMachine.new(user_actions_dir: ACTIONS_DIR)
    sm.include_module('SmMessenger')
    sm.insert_path_to_hosts(
      File.absolute_path('./lib/sm_messenger/resources/hosts.json')
    )
    sm.load_actions
    sm.execute
  end
end
