require 'state/actions/parent_action'

class ActionProcessOutboundMessage < ParentAction
  # Instantiate the action
  # @param args [Hash] Required parameters for the action
  # run_mode [Symbol] Either NORMAL or RECOVER
  # sqlite3_db [Symbol] Path to the main control DB
  # logger [Symbol] The logger object for logging
  def initialize(args, flag)
    @flag = flag
    if args[:run_mode] == 'NORMAL'
      @phase = 'RUNNING'
      @activation = 'ACT'
      @payload = 'NULL'
      super(args[:logger])
    else
      recover_action(self)
    end
  end

  # Do the work for this action
  def execute
    return unless active
    process_outbound_message
    # deactivate(@flag)
  end

  private

  # States for this action
  def states
    []
  end

  def process_outbound_message
    execute_sql_query(
      'select id, sender, action, payload, date_time ' +
      'from messages where processed = 0 and direction = \'out\''
    ).each do |msg|
      # Create the ack
      builder = MessageBuilder.new()
      builder.sender = msg[1]
      builder.action = msg[2]
      builder.payload = msg[3]
      builder.date_time = msg[4]
      builder.direction = 'out'
      json = builder.build(msg[0])

      # Write it to the outbound directory
      write_ack_to_file(json, builder.id)
    end
  end

  def write_ack_to_file(json, id)
    file = query_property('out_pending') + '/' + id
    File.write(file, json)
    File.write(file + '.flag', '')
  end
end