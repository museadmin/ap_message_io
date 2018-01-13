require 'ap_message_io/version'
require 'state_machine'

# Modules can be added to state machine and methods called
# from messenger gem using .include_module method
class ApMessageIo
  # Relative path to our actions
  ACTIONS_DIR = '/lib/ap_message_io/actions'.freeze

  def initialize(**args)
    export_action_pack(args) unless args.empty?
  end

  # Export the actions from this pack into a state machine
  def export_action_pack(args)
    root = File.expand_path('../..', __FILE__)
    path = root + ACTIONS_DIR
    path = root + '/' + args[:dir] unless args[:dir].nil?
    args[:state_machine].import_action_pack(path)
  end
end

# Module contains methods for state machine that help the
# messaging action pack
module ApMessageIoModule
  # Get the runtime messaging directories
  def in_pending
    query_property('in_pending')
  end

  def in_processed
    query_property('in_processed')
  end

  def out_pending
    query_property('out_pending')
  end

  def out_processed
    query_property('out_processed')
  end

  # Test method to prove export of module to state machine
  def test_method
    'Test String'
  end
end