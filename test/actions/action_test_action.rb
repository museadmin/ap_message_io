require 'state/actions/parent_action'

# A test Action
class ActionTestAction < ParentAction
  # Instantiate the action
  # @param args [Hash] Required parameters for the action
  # run_mode [Symbol] Either NORMAL or RECOVER
  # sqlite3_db [Symbol] Path to the main control DB
  # logger [Symbol] The logger object for logging
  def initialize(args, flag)
    @flag = flag
    if args[:run_mode] == 'NORMAL'
      @phase = 'ALL'
      @activation = 'ACT'
      @payload = 'NULL'
      super(args[:sqlite3_db], args[:logger])
    else
    recover_action(self)
    end
  end

  # Do the work for this action
  def execute
    return unless active
    puts 'Shutting down from ActionTestAction'
    normal_shutdown
  end

  private

  # States for this action
  def states
    [
      ['0', 'TEST_ACTION_LOADED', 'Test state been loaded into DB']
    ]
  end
end
