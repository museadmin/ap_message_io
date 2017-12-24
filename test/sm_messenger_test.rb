require 'test_helper'

class SmMessengerTest < Minitest::Test
  ACTIONS_DIR = './test/actions'.freeze

  def test_that_it_has_a_version_number
    refute_nil ::SmMessenger::VERSION
  end

  def test_it_loads_user_actions
    sm = StateMachine.new(user_actions_dir: ACTIONS_DIR)
    sm.load_actions
    sm.execute
  end
end
