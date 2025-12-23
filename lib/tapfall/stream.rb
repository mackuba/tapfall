require 'forwardable'
require 'skyfall/stream'

require_relative 'api'
require_relative 'errors'
require_relative 'messages/tap_message'
require_relative 'version'

module Tapfall
  class Tapfall::Stream < Skyfall::Stream
    extend Forwardable

    def_delegators :@api, :add_repo, :add_repos, :remove_repo, :remove_repos, :resolve_did

    def initialize(server, options = {})
      super(server)

      @options = options
      @root_url = ensure_empty_path(@root_url)
      @ack = true unless options[:ack] == false
      @password = options[:admin_password]

      @api = build_api
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

    # TMP
    def send_data(data)
      @ws.send(data)
    end

    def build_websocket_client(url)
      Faye::WebSocket::Client.new(url, nil, { headers: { 'User-Agent' => user_agent }.merge(request_headers) })
    end

    def ensure_empty_path(url)
      url = url.chomp('/')

      if URI(url).path != ''
        raise ArgumentError, "Server URL should only include a hostname, without any path"
      end

      url
    end
    # END

    def basic_auth(account, password)
      'Basic ' + ["#{account}:#{password}"].pack('m0')
    end

    def request_headers
      if @password
        { 'Authorization' => basic_auth('admin', @password) }
      else
        {}
      end
    end

    def build_websocket_url
      @root_url + "/channel"
    end

    def build_api_url
      if @root_url.start_with?('ws://')
        @root_url.gsub(/^ws:/, 'http:')
      else
        @root_url.gsub(/^wss:/, 'https:')
      end
    end

    def build_api
      api_url = build_api_url
      API.new(api_url, { admin_password: @password })
    end
  end
end
