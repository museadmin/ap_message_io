require 'state/actions/parent_action'

# A test Action
class ActionTestAction < ParentAction
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

  def states
    [
      ['0', 'TEST_ACTION_LOADED', 'Test state been loaded into DB']
    ]
  end

  def execute
    return unless active
    puts 'Shutting down from ActionTestAction'
    normal_shutdown
  end
end
