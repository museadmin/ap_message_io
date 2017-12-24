require 'state/actions/parent_action'

# A test Action
class ActionTestAction < ParentAction
  @states = [
    ['0', 'TEST_ACTION_LOADED', 'Test state been loaded into DB']
  ]

  def initialize(control)
    if control[:run_state] == 'NORMAL'
      @phase = 'ALL'
      @activation = 'ACT'
      @payload = 'NULL'
      super(control)
    else
    recover_action(self)
    end
  end

  def execute(control)
    if active
      puts 'Shutting down from ActionTestAction'
      normal_shutdown(control)
    end
  ensure
    update_action(self)
  end
end
