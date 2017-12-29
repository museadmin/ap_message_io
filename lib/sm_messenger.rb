require 'sm_messenger/version'
require 'state_machine'

# Modules can be added to state machine and methods called
# from messenger gem using .include_module method
module SmMessenger

end

# Module for unit test
module TestModule
  def test_method
    'Test String'
  end
end
