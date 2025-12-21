require 'json'
require_relative '../errors'

module Tapfall
  class TapMessage
    attr_reader :id, :type
    alias seq id

    # :nodoc: - consider this as semi-private API
    attr_reader :json

    def self.new(data)
      require_relative 'identity_message'
      require_relative 'record_message'
      require_relative 'unknown_message'

      json = JSON.parse(data)

      message_class = case json['type']
        when 'record'   then RecordMessage
        when 'identity' then IdentityMessage
        else UnknownMessage
      end

      message = message_class.allocate
      message.send(:initialize, json)
      message
    end

    def initialize(json)
      @json = json
      @type = @json['type'].to_sym
      @id = @json['id']
    end

    def unknown?
      self.is_a?(UnknownMessage)
    end

    def operations
      []
    end
  end
end
