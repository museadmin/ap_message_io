require 'ap_message_io/version'
require 'state_machine'

# Modules can be added to state machine and methods called
# from messenger gem using .include_module method
class ApMessageIo
  def export_action_pack(state_machine, path)
    state_machine.import_action_pack(path)
  end
end

# Module for unit test
module TestModule
  def test_method
    'Test String'
  end
end
