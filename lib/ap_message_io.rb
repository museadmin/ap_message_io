require 'ap_message_io/version'
require 'state_machine'
require_relative 'ap_message_io/api/api_server'

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
  get "/" do
    ApiServer::Base::SM.query_property('out_processed')
  end
end

# Module contains methods for state machine that help the
# messaging action pack
module ApMessageIoModule

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

  # Start the API Server in a Background thread
  def start_api_server
    # Add a state_machine reference to the Api server so it can
    # access the SM's methods etc.
    ApiServer::Base.const_set('SM', self)
    # Now run the server under WEBrick in a BG thread
    Thread::abort_on_exception
    @msg_api_server = Thread.new do
      Rack::Handler::WEBrick.run(
        ApiServer::Application,
        Port: 4567,
        Logger: WEBrick::Log::new($stderr, WEBrick::Log::ERROR)
      )
    end
  end

  # Stop the Api Server
  def stop_api_server
    Rack::Handler::WEBrick.shutdown
    sleep(2)
    Thread.kill(@msg_api_server)
  end

  # Unit test method to prove export of module to state machine
  def test_method
    'Test String'
  end
end