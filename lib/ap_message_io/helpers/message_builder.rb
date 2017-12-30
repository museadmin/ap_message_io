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
      ack: true,
      date_time: nil
    }
  end

  # Build the message as a json string
  def build
    epoch = (Time.now.to_f * 1000).to_i
    @message[:id] = "#{@message[:sender]}_#{epoch}"
    @message[:date_time] = Time.at(epoch / 1000)
    JSON.generate(@message)
  end

  # Return the message id
  def id
    @message[:id]
  end

  # Set sender field to Hostname of sender
  # @param hostname [String] Hostname of sender
  def sender=(hostname)
    @message[:sender] = hostname
  end

  # Set the action flag
  # @param action [String] Flag for action
  def action=(action)
    @message[:action] = action
  end

  # Optional payload for action being activated
  def payload=(payload)
    @message[:payload] = payload
  end

  # Ack is set true in recipient when ack is sent
  def ack=(ack)
    raise 'Invalid ack flag. true or false expected' unless
      [true, false].include? ack
    @message[:ack] = ack
  end
end