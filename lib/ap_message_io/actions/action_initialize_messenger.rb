require 'state/actions/parent_action'

# Load the properties for the messenger into the control DB
# and create the in and outbound messaging directories
class ActionInitializeMessenger < ParentAction
  # Instantiate the action
  # @param args [Hash] Required parameters for the action
  # run_mode [Symbol] Either NORMAL or RECOVER
  # logger [Symbol] The logger object for logging
  def initialize(args, flag)
    @flag = flag
    if args[:run_mode] == 'NORMAL'
      @phase = 'STARTUP'
      @activation = 'ACT'
      @payload = 'NULL'
    else
      recover_action(self)
    end
    super(args[:logger])
  end

  # Do the work for this action
  def execute
    return unless active
    create_dirs
    create_message_table
    update_state('INIT_MESSAGING_LOADED', 1)
    @logger.info('Messenger dependencies created Successfully')
    activate(flag: 'ACTION_CHECK_FOR_INBOUND_MESSAGES')
    activate(flag: 'ACTION_PROCESS_OUTBOUND_MESSAGES')
    deactivate(@flag)
  end

  private

  # States for this action
  def states
    [
      ['0', 'INIT_MESSAGING_LOADED', 'Properties have been loaded into DB']
    ]
  end

  # Create the messages table in the DB
  def create_message_table
    execute_sql_statement("CREATE TABLE messages (\n" \
      "   id CHAR PRIMARY KEY, \n" \
      "   sender CHAR NOT NULL, -- Hostname of sender \n" \
      "   action CHAR NOT NULL, -- The action to perform \n" \
      "   payload CHAR, -- Optional payload \n" \
      "   ack INTEGER DEFAULT 0, -- ack sent \n" \
      "   date_time CHAR NOT NULL, -- Time sent \n" \
      "   direction CHAR DEFAULT 'in', -- In or out bound msg \n" \
      "   processed INTEGER DEFAULT 0 \n" \
      ");".strip)
  end

  # Create the inbound and outbound dirs under the run dir
  def create_dirs
    run_dir = query_property('run_dir')
    raise 'Run directory not found' unless Dir.exist?(run_dir)

    create_dir("#{run_dir}/messaging/in_pending", 'in_pending')
    create_dir("#{run_dir}/messaging/in_processed", 'in_processed')
    create_dir("#{run_dir}/messaging/out_pending", 'out_pending')
    create_dir("#{run_dir}/messaging/out_processed", 'out_processed')
    FileUtils.chmod_R('u=wrx,go=r', run_dir)
  end

  # Physically create a directory and record its path
  # in DB properties table
  # @param path [String] Path to directory
  # @param property [String] Name for property
  def create_dir(path, property)
    FileUtils.mkdir_p(path)
    insert_property(property, path)
  end
end
