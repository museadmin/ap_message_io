require 'state/actions/parent_action'

# Send an ack for a message received
class ActionSendAck < ParentAction
  def initialize(args, flag)
    @flag = flag
    if args[:run_mode] == 'NORMAL'
      @phase = 'RUNNING'
      @activation = 'SKIP'
      @payload = 'NULL'
      super(args[:sqlite3_db], args[:logger])
    else
      recover_action(self)
    end
  end

  def states
    []
  end

  def execute
    return unless active

    deactivate(@flag)
  end

  def process_outbound_ack
    # TODO: Write to message file in outbound dir
    # Do I need a required flag for acks....
  end
end