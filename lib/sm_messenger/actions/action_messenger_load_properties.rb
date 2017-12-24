require 'state/actions/parent_action'

# Load the properties for the messenger into the control DB
class ActionMessengerLoadProperties < ParentAction
  @states = [
    ['0', 'PROPERTIES_LOADED', 'Properties have been loaded into DB']
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
      puts @flag
      control[:actions]['NORMAL_SHUTDOWN'].activation = 'ACT'
    end
  ensure
    update_action(self)
  end
end
