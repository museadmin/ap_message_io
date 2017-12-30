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
    process_outbound_ack
    deactivate(@flag)
  end

  private

  # States for this action
  def states
    []
  end

  def process_outbound_ack
    execute_sql_query(
        'select id from messages where processed = 1 and ack = 0'
    ).each do |message|
      # Create the ack
      builder = MessageBuilder.new()
      builder.sender = `hostname`.strip
      builder.action = 'ACK'
      builder.payload = message[0]
      json = builder.build
      # Write it to the outbound directory
      write_ack_to_file(json, builder.id)
      # Insert a record of it into the db messages table
      insert_message_to_db(builder)
      # Update the ack field in the original message
      update_original_message(builder)
    end
  end

  def update_original_message(builder)
    execute_sql_statement(
        "update messages set ack = 1 where id = '#{builder.id}'"
    )
  end

  def insert_message_to_db(builder)
    sql = "insert into messages \n" \
      "(id, sender, action, payload, ack, date_time) \n" \
      "values\n" \
      "('#{builder.id}', '#{builder.sender}', '#{builder.action}', \n" \
      " '#{builder.payload}', '0', '#{builder.date_time}');"

    execute_sql_statement(sql)
  end

  def write_ack_to_file(json, id)
    file = query_property('out_pending') + '/' + id
    File.write(file, json)
    File.write(file + '.flag', '')
  end
end