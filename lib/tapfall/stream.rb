require 'skyfall/stream'
require_relative 'messages/tap_message'
require_relative 'version'

module Tapfall
  class Tapfall::Stream < Skyfall::Stream
    def initialize(server, options = {})
      super(server)

      @options = options
      @root_url = ensure_empty_path(@root_url)
      @ack = true unless options[:ack] == false
    end

    def connect
      if @ack && @handlers[:message].nil?
        raise ConfigError, "The on(:message) handler must be set unless :ack => false option is passed"
      end

      super
    end

    def handle_message(packet)
      data = packet.data
      @handlers[:raw_message]&.call(data)

      if @handlers[:message]
        tap_message = TapMessage.new(data)
        @handlers[:message].call(tap_message)
        send_ack(tap_message) if @ack
      end
    end

    def send_ack(msg)
      json = %({"type":"ack","id":#{msg.id}})
      send_data(json)
    end

    private

    def build_websocket_url
      @root_url + "/channel"
    end
  end
end
