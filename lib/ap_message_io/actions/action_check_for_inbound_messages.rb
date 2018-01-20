require 'state/actions/parent_action'
require 'fileutils'

# Check the inbound directory for new messages
class ActionCheckForInboundMessages < ParentAction

  attr_reader :action

  # Instantiate the action, args hash
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
    in_pending = query_property('in_pending')
    Dir["#{in_pending}/*.flag"].each do |action_file|
      insert_message(action_file)
      move_message_to_processed(action_file)
      update_state('UNREAD_MESSAGES', 1)
      activate(action: 'ACTION_PROCESS_INBOUND_MESSAGE')
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
  # @param action_file [String] Path to the semaphore file
  def insert_message(action_file)
    msg_file = "#{File.dirname(action_file)}/#{File.basename(action_file, '.*')}"
    msg = JSON.parse(File.read(msg_file))

    execute_sql_statement("insert into messages \n" \
      "(id, sender, action, activation, payload, ack, direction, date_time) \n" \
      "values\n" \
      "('#{msg['id']}', '#{msg['sender']}', \n" \
      "'#{msg['action']}', '#{msg['activation']}', \n" \
      " '#{msg['payload']}', '0', 'in', '#{msg['date_time']}');")
  end

  # After the message has been inserted into the DB
  # move it to processed dir
  # @param action_file [String] Path to the semaphore file
  def move_message_to_processed(action_file)
    # Move the data file first
    source = "#{File.dirname(action_file)}/#{File.basename(action_file, '.*')}"
    target = "#{query_property(
      'in_processed'
    )}/#{File.basename(action_file, '.*')}"
    FileUtils.move source, target
    # Then the semaphore
    source = action_file
    target = "#{query_property('in_processed')}/#{File.basename(action_file)}"
    FileUtils.move source, target
  end
end