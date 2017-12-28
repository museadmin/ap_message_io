require 'sm_messenger/version'
require 'state_machine'

# Modules can be added to state machine and methods called
# from messenger gem using .include_module method
module SmMessenger
  # def insert_path_to_hosts(host_file)
  #   insert_property('host_file', host_file)
  # end
end

# Module for unit test
module TestModule
  def test_method
    'Test String'
  end
end

# Main messenger class
# class MessageManager
#   def initialize(args)
#     puts 'in init'
#   end
# end