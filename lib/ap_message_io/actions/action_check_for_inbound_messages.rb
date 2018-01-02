require 'state/actions/parent_action'
require 'fileutils'

# Check the inbound directory for new messages
class ActionCheckForInboundMessages < ParentAction
  # Instantiate the action, args hash contains:
  # run_mode [Symbol] Either NORMAL or RECOVER,
  # sqlite3_db [Symbol] Path to the main control DB,
  # logger [Symbol] The logger object for logging.
  # @param args [Hash] Required parameters for the action
  def initialize(args, flag)
    @flag = flag
    if args[:run_mode] == 'NORMAL'
      @phase = 'RUNNING'
      @activation = 'SKIP'
      @payload = 'NULL'
      super(args[:logger])
    else
      recover_action(self)
    end
  end

  # Do the work for this action
  def execute
    return unless active
    in_pending = query_property('in_pending')
    Dir["#{in_pending}/*.flag"].each do |flag_file|
      insert_message(flag_file)
      move_message_to_processed(flag_file)
      update_state('UNREAD_MESSAGES', 1)
      activate(flag: 'ACTION_PROCESS_INBOUND_MESSAGE')
    end
  end

  private

  # States for this action
  def states
    [
      ['0', 'UNREAD_MESSAGES', 'New messages found in inbound dir']
    ]
  end

  # Found a message so insert it into the DB
  # @param flag_file [String] Path to the semaphore file
  def insert_message(flag_file)
    msg_file = "#{File.dirname(flag_file)}/#{File.basename(flag_file, '.*')}"
    msg = JSON.parse(File.read(msg_file))

    execute_sql_statement("insert into messages \n" \
      "(id, sender, action, payload, ack, direction, date_time) \n" \
      "values\n" \
      "('#{msg['id']}', '#{msg['sender']}', '#{msg['action']}', \n" \
      " '#{msg['payload']}', '0', 'in', '#{msg['date_time']}');")
  end

  # After the message has been inserted into the DB
  # move it to processed dir
  # @param flag_file [String] Path to the semaphore file
  def move_message_to_processed(flag_file)
    # Move the data file first
    source = "#{File.dirname(flag_file)}/#{File.basename(flag_file, '.*')}"
    target = "#{query_property(
      'in_processed'
    )}/#{File.basename(flag_file, '.*')}"
    FileUtils.move source, target
    # Then the semaphore
    source = flag_file
    target = "#{query_property('in_processed')}/#{File.basename(flag_file)}"
    FileUtils.move source, target
  end
end