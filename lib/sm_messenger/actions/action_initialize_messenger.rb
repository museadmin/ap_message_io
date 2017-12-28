require 'state/actions/parent_action'

# Load the properties for the messenger into the control DB
# and create the in and outbound messaging directories
class ActionInitializeMessenger < ParentAction
  def initialize(args, flag)
    @flag = flag
    if args[:run_mode] == 'NORMAL'
      @phase = 'STARTUP'
      @activation = 'ACT'
      @payload = 'NULL'
      super(args[:sqlite3_db], args[:logger])
    else
      recover_action(self)
    end
  end

  def states
    [
      ['0', 'INIT_MESSAGING_LOADED', 'Properties have been loaded into DB']
    ]
  end

  def execute
    return unless active
    create_dirs
    create_message_table
    update_state('INIT_MESSAGING_LOADED', 1)
    @logger.info('Messenger dependencies created Successfully')
    activate('ACTION_CHECK_FOR_INBOUND_MESSAGES')
    deactivate(@flag)
  end

  def create_message_table
    execute_sql_statement('CREATE TABLE messages (' \
      '   id CHAR PRIMARY KEY, ' \
      "   sender CHAR NOT NULL, -- Hostname of sender \n" \
      "   action CHAR NOT NULL, -- The action to perform \n" \
      "   payload CHAR, -- Optional payload \n" \
      "   ack CHAR NOT NULL, -- ack sent \n" \
      "   date_time CHAR NOT NULL, -- Time sent \n" \
      "   processed INTEGER DEFAULT 0 \n" \
      ");".strip)
  end

  def create_dirs
    run_dir = query_property('run_dir')
    raise 'Run directory not found' unless Dir.exist?(run_dir)

    create_dir("#{run_dir}/messaging/in_pending", 'in_pending')
    create_dir("#{run_dir}/messaging/in_processed", 'in_processed')
    create_dir("#{run_dir}/messaging/out_pending", 'out_pending')
    create_dir("#{run_dir}/messaging/out_processed", 'out_processed')
    FileUtils.chmod_R('u=wrx,go=r', run_dir)
  end

  def create_dir(path, property)
    FileUtils.mkdir_p(path)
    insert_property(property, path)
  end
end
