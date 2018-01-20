require 'state/actions/parent_action'

# Process inbound messages
class ActionProcessInboundMessage < ParentAction

  attr_reader :action

  # Instantiate the action
  # @param args [Hash] Required parameters for the action
  # @action [String] Name of action
  def initialize(args, action)
    @action = action
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
    deactivate(@action)
    activate(action: 'ACTION_SEND_ACK')
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
      activate(payload: msg[MSG_PAYLOAD], action: msg[MSG_ACTION])
    end
  end
end