require 'state/actions/parent_action'

# Process inbound messages
class ActionProcessInboundMessage < ParentAction
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
    []
  end

  def execute
    return unless active
    process_messages
    deactivate(@flag)
  end

  def process_messages
    execute_sql_query(
      'select * from messages where processed = 0;'
    ).each do |msg|
      execute_sql_statement(
        'update messages set processed = \'1\' ' \
        "where id = '#{msg[0]}';"
      )
      activate(payload: msg[3], flag: msg[2])
    end
  end
end