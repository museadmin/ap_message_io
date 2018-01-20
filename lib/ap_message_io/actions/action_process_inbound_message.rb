require 'state/actions/parent_action'

# Process inbound messages
class ActionProcessInboundMessage < ParentAction

  attr_reader :flag

  # Instantiate the action
  # @param args [Hash] Required parameters for the action
  # run_mode [Symbol] Either NORMAL or RECOVER
  # logger [Symbol] The logger object for logging
  def initialize(args, flag)
    @flag = flag
    if args[:run_mode] == 'NORMAL'
      @phase = 'RUNNING'
      @activation = SKIP
      @payload = 'NULL'
    else
      recover_action(self)
    end
    super(args[:logger])
  end

  # Do the work for this action
  def execute
    return unless active
    process_messages
    update_state('UNREAD_MESSAGES', 0)
    deactivate(@flag)
    activate(flag: 'ACTION_SEND_ACK')
  end

  private

  # States for this action
  def states
    []
  end

  # Find each unprocessed message in the DB and process it
  # Setting each one's action and optional payload
  # TODO: This assumes that the message is always to activate...
  def process_messages
    execute_sql_query(
      "select id, sender, action, activation, \n" \
      "payload, ack, date_time, direction, processed \n" \
      "from messages where processed = 0 and direction = 'in';"
    ).each do |msg|
      execute_sql_statement(
        'update messages set processed = \'1\' ' \
        "where id = '#{msg[MSG_ID]}';"
      )
      activate(payload: msg[MSG_PAYLOAD], flag: msg[MSG_ACTION])
    end
  end
end