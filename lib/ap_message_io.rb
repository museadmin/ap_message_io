
require_relative 'ap_message_io/api/api_server'
require 'ap_message_io/helpers/message_builder'
require 'ap_message_io/version'
require 'json'
require 'rack'
require 'state_machine'
# require 'ap_message_io/resources/constants'

# Modules can be added to state machine and methods called
# from messenger gem using .include_module('name') method
class ApMessageIo
  # Relative path to our actions
  ACTIONS_DIR = '/lib/ap_message_io/actions'.freeze
  def initialize(args)
    export_action_pack(args)
    args[:state_machine].include_module('ApMessageIoModule')
  end

  # Export the actions from this pack into a state machine
  def export_action_pack(args)
    root = File.expand_path('../..', __FILE__)
    path = root + ACTIONS_DIR
    path = root + '/' + args[:dir] unless args[:dir].nil?
    args[:state_machine].import_action_pack(path)
  end
end

# The routing for the endpoints. Needs to be careful not to
# do any writes to the DB directly. Only via an inbound message
# Should be able to read ok though, as sqlite3 supports concurrent reads
# State Machine is referenced via the constant: ApiServer::Base::SM
module ApiRoutes
  get '/properties' do
    [200, {}, [ApiServer::Base::SM.properties]]
    # ApiServer::Base::SM.properties
  end
  post '/message' do
    ApiServer::Base::SM.message(JSON.parse(request.body.read))
    [201,  {}, ['{ "status": "Message Received" }']]
  end
end

module Logging
  # Fatal log level which indicates a server crash
  FATAL = 1
  # Error log level which indicates a recoverable error
  ERROR = 2
  # Warning log level which indicates a possible problem
  WARN  = 3
  # Information log level which indicates possibly useful information
  INFO  = 4
  # Debugging error level for messages used in server development or
  # debugging
  DEBUG = 5
end

# Module contains methods for state machine that help the
# messaging action pack
module ApMessageIoModule
  include Logging
  # Return the pending inbound messaging directory
  def in_pending_dir
    query_property('in_pending')
  end
  # Return the processed inbound messaging directory
  def in_processed_dir
    query_property('in_processed')
  end
  # Return the pending outbound messaging directory
  def out_pending_dir
    query_property('out_pending')
  end
  # Return the processed outbound messaging directory
  def out_processed_dir
    query_property('out_processed')
  end

  # Service api route '/properties'
  def properties
    execute_sql_query(
      "select property, value from properties order by property asc;"
    ).to_json
  end

  # Server API route '/message'
  def message(params)
    js = JSON.generate(params)
    write_message_to_file(js)
  end

  # Start the API Server in a Background thread
  def start_api_server(**args)
    port = args.fetch(:port, 4567)
    log_level = args.fetch(:log_level, Logging::ERROR)

    # Add a state_machine reference to the Api server so it can
    # access the SM's methods etc. if not already defined
    ApiServer::Base.const_set('SM', self) if (defined? ApiServer::Base::SM).nil?

    # Now run the server under WEBrick in a BG thread
    Thread::abort_on_exception
    @msg_api_server = Thread.new do
      Rack::Handler::WEBrick.run(
        ApiServer::Application,
        Port: port,
        Logger: WEBrick::Log::new($stderr, log_level)
      )
    end
  end

  # Stop the Api Server
  def stop_api_server
    Rack::Handler::WEBrick.shutdown
    sleep(2)
    Thread.kill(@msg_api_server)
  end

  # Drop an action message into the queue with an action flag
  # TODO: Add ACT or SKIP to message, default to ACT in builder
  def create_action_message(flag)
    js = build_message(flag)
    write_message_to_file(js)
  end

  # Write the message to file
  def write_message_to_file(js)
    in_pending = in_pending_dir
    name = JSON.parse(js)['id']
    File.open("#{in_pending}/#{name}", 'w') { |f| f.write(js) }
    File.open("#{in_pending}/#{name}.flag", 'w') { |f| f.write('') }
  end

  # Build a test message
  def build_message(flag, payload = nil)
    builder = MessageBuilder.new
    builder.sender = 'localhost'
    builder.action = flag
    builder.payload = payload.nil? ? '{ "test": "value" }' : payload
    builder.direction = 'in'
    builder.build
  end

  # Unit test method to prove export of module to state machine
  def test_method
    'Test String'
  end
end