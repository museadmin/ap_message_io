require 'state/actions/parent_action'
require 'fileutils'

# Check the inbound directory for new messages
class ActionCheckForInboundMessages < ParentAction
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
    [
      ['0', 'UNREAD_MESSAGES', 'New messages found in inbound dir']
    ]
  end

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

  def insert_message(flag_file)
    msg_file = "#{File.dirname(flag_file)}/#{File.basename(flag_file, '.*')}"
    msg = JSON.parse(File.read(msg_file))

    execute_sql_statement("insert into messages \n" \
      "(id, sender, action, payload, ack, date_time) \n" \
      "values\n" \
      "('#{msg['id']}', '#{msg['sender']}', '#{msg['action']}', \n" \
      " '#{msg['payload']}', '0', '#{msg['date_time']}');")
  end

  def move_message_to_processed(flag_file)
    # Move the data file first
    source = "#{File.dirname(flag_file)}/#{File.basename(flag_file, '.*')}"
    target = "#{query_property('in_processed')}/#{File.basename(flag_file, '.*')}"
    FileUtils.move source, target
    # Then the semaphore
    source = flag_file
    target = "#{query_property('in_processed')}/#{File.basename(flag_file)}"
    FileUtils.move source, target
  end
end