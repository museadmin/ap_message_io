require 'state/actions/parent_action'

# A test Action
class ActionTestAction < ParentAction

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
    builder = MessageBuilder.new
    builder.sender = `hostname`.strip
    builder.action = 'THIRD_PARTY_ACTION'
    builder.payload = '{ "test": "value" }'
    builder.direction = 'out'
    builder.processed = 0
    builder.build

    inject_outbound_message(builder)
    deactivate(@flag)
  end

  private

  # States for this action
  def states
    [
      ['0', 'TEST_ACTION_LOADED', 'Test state been loaded into DB']
    ]
  end

  # Inject an outbound message into the DB
  def inject_outbound_message(builder)
    sql = "insert into messages \n" \
      "(id, sender, action, payload, ack, direction, date_time) \n" \
      "values\n" \
      "('#{builder.id}', '#{builder.sender}', '#{builder.action}', \n" \
      " '#{builder.payload}', '0', 'out', '#{builder.date_time}');"

    execute_sql_statement(sql)
  end
end
