require 'ap_message_io/version'
require 'state_machine'

# Modules can be added to state machine and methods called
# from messenger gem using .include_module method
# TODO: Create a runner project that includes sm and this one then
# write a test that exports to sm vis this function
class ApMessageIo
  def export_action_pack(state_machine)
    path = File.expand_path('../', __FILE__)
    state_machine.import_action_pack(path + '/ap_message_io/actions')
  end
end

# Module for unit test
module TestModule
  def test_method
    'Test String'
  end
end
