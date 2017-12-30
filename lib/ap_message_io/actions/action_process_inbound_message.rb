require 'state/actions/parent_action'

# Process inbound messages
class ActionProcessInboundMessage < ParentAction
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
  def process_messages
    execute_sql_query(
      'select * from messages where processed = 0;'
    ).each do |msg|
      execute_sql_statement(
        'update messages set processed = \'1\' ' \
        "where id = '#{msg[0]}';"
      )
      activate(payload: msg[3], flag: msg[2])
    end
  end
end