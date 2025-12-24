require_relative '../errors'
require_relative 'operation'
require_relative 'tap_message'

module Tapfall
  class IdentityMessage < TapMessage
    def initialize(json)
      raise DecodeError.new("Missing event details") if json['identity'].nil?
      @identity = json['identity']

      super
    end

    def did
      @identity['did']
    end

    def handle
      @identity['handle']
    end

    def active?
      @identity['isActive'] || @identity['is_active']
    end

    def status
      @identity['status']&.to_sym
    end
  end
end
