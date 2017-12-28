require 'json'

class MessageBuilder
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

  def build
    epoch = (Time.now.to_f * 1000).to_i
    @message[:id] = "#{@message[:sender]}_#{epoch}"
    @message[:date_time] = Time.at(epoch/1000)
    JSON.generate(@message)
  end

  def id
    @message[:id]
  end

  def sender=(hostname)
    @message[:sender] = hostname
  end

  def action=(action)
    @message[:action] = action
  end

  def payload=(payload)
    @message[:payload] = payload
  end

  def ack=(ack)
    raise 'Invalid ack flag. true or false expected' unless
      ack == true || ack == false
    @message[:ack] = ack
  end
end