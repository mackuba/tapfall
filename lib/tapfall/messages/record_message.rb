require_relative '../errors'
require_relative 'operation'

module Tapfall
  class RecordMessage < TapMessage
    def initialize(json)
      raise DecodeError.new("Missing record details") if json['record'].nil?
      super
    end

    def operation
      @operation ||= Operation.new(json['record'])
    end

    def operations
      [operation]
    end

    alias op operation
  end
end
