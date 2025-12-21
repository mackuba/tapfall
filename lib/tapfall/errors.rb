module Tapfall
  class BadResponseError < StandardError
    attr_reader :status, :data

    def initialize(status, status_message, data)
      @status = status
      @data = data

      message = if error_message
        "#{status} #{status_message}: #{error_message}"
      else
        "#{status} #{status_message}"
      end

      super(message)
    end

    def error_type
      @data['error'] if @data.is_a?(Hash)
    end

    def error_message
      @data['message'] if @data.is_a?(Hash)
    end
  end

  class ConfigError < StandardError
  end

  class DecodeError < StandardError
  end
end
