require 'state/actions/parent_action'
require 'json'

# Create the hosts table in the db and populate it
class ActionInitializeHosts < ParentAction
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
      ['0', 'INIT_HOSTS_LOADED', 'Host data have been loaded into DB']
    ]
  end

  def execute
    return unless active
    create_hosts_table
    populate_hosts_table
    update_state('INIT_HOSTS_LOADED', 1)
    deactivate(@flag)
    # normal_shutdown
  end

  def create_hosts_table
    execute_sql_statement("CREATE TABLE hosts\n" \
      "(\n"  \
      "   host_id INTEGER PRIMARY KEY, \n" \
      "   hostname CHAR NOT NULL, -- Fully qualified hostname \n" \
      "   short_name CHAR NOT NULL, -- Short hostname \n" \
      "   ipv4 CHAR, -- IPV4 IP address \n" \
      "   ipv6 CHAR, -- IPV6 IP address \n" \
      "   host_group CHAR, -- User defined group e.g. Foreman \n" \
      "   type CHAR -- User defined type e.g. PRX for a proxy \n" \
      ");".strip)
  end

  def populate_hosts_table
    host_file = query_property('host_file')
    raise 'Failed to find host file' unless File.file?(host_file)
    hosts = JSON.parse(File.read(host_file))
    hosts['hosts'].each do |host|
      execute_sql_statement("insert into hosts \n" \
        "(hostname, short_name, ipv4, ipv6, host_group, type) \n" \
        "values \n" \
        "('#{host['hostname']}', '#{host['short_name']}', '#{host['ipv4']}', \n" \
        "'#{host['ipv6']}', '#{host['host_group']}', '#{host['type']}') \n" \
        ";".strip)
    end
  end
end