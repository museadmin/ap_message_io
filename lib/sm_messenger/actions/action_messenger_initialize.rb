require 'state/actions/parent_action'

# Load the properties for the messenger into the control DB
# and create the in and outbound messaging directories
class ActionMessengerInitialize < ParentAction
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
      ['0', 'INIT_PROPERTIES_LOADED', 'Properties have been loaded into DB']
    ]
  end

  def execute
    return unless active
    create_dirs
    update_state('INIT_PROPERTIES_LOADED', 1)
    @logger.info('Messenger Properties Loaded Successfully')
    activate('ACTION_INITIALIZE_HOSTS')
    deactivate(@flag)
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
