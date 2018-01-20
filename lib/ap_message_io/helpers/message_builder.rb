require 'json'

# Build a message file
class MessageBuilder
  # Create a hash of nil values for message
  def initialize
    @message = {
      id: nil,
      sender: nil,
      action: nil,
      payload: nil,
      activation: 1,
      direction: 'in',
      date_time: nil
    }
  end

  # Build the message as a json string
  def build(id = nil)
    epoch = (Time.now.to_f * 1000).to_i
    id.nil? ? @message[:id] = "#{@message[:sender]}_#{epoch}" : @message[:id] = id
    @message[:date_time] = Time.at(epoch / 1000)
    JSON.generate(@message)
  end

  # Return the message id
  def id
    @message[:id]
  end

  # Return the activation level
  def activation
    @message[:activation]
  end

  # Return the sender
  def sender
    @message[:sender]
  end

  # Return the action
  def action
    @message[:action]
  end

  # Return the payload
  def payload
    @message[:payload]
  end

  # Return the direction
  def direction
    @message[:direction]
  end

  # Return the time stamp
  def date_time
    @message[:date_time]
  end

  # Return processed
  def processed
    @message[:processed]
  end

  # Set sender field to Hostname of sender
  # @param hostname [String] Hostname of sender
  def sender=(hostname)
    @message[:sender] = hostname
  end

  # Set the action action
  # @param action [String] Name for action
  def action=(action)
    @message[:action] = action
  end

  # Set the activation
  # @param activation [Integer] 1 = active 0 = skip
  def activation=(activation)
    @message[:activation] = activation
  end

  # Optional payload for action being activated
  def payload=(payload)
    @message[:payload] = payload
  end

  # Return the direction
  def direction=(direction)
    @message[:direction] = direction
  end

  # Ack is set true in recipient when ack is sent
  def ack=(ack)
    raise 'Invalid ack status. true or false expected' unless
      [true, false].include? ack
    @message[:ack] = ack
  end

  # Set the processed flag
  def processed=(value)
    @message[:processed] = value
  end

  def date_time=(date_time)
    @message[:date_time] = date_time
  end
end