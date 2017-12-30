require 'state/actions/parent_action'

# Send an ack for a message received
class ActionSendAck < ParentAction
  # Instantiate the action
  # @param args [Hash] Required parameters for the action
  # run_mode [Symbol] Either NORMAL or RECOVER
  # sqlite3_db [Symbol] Path to the main control DB
  # logger [Symbol] The logger object for logging
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

  # Do the work for this action
  def execute
    return unless active

    deactivate(@flag)
  end

  private

  # States for this action
  def states
    []
  end

  def process_outbound_ack
    # TODO: Write to message file in outbound dir
    # Do I need a required flag for acks....
  end
end