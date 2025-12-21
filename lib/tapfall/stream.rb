require 'skyfall/stream'
require_relative 'version'
require_relative 'messages/tap_message'

class Tapfall::Stream < Skyfall::Stream
  def initialize(server)
    super(server)

    @root_url = ensure_empty_path(@root_url)
  end

  def handle_message(msg)
    data = msg.data
    @handlers[:raw_message]&.call(data)

    if @handlers[:message]
      tap_message = Tapfall::TapMessage.new(data)
      @handlers[:message].call(tap_message)
    end
  end

  private

  def build_websocket_url
    @root_url + "/channel"
  end
end
