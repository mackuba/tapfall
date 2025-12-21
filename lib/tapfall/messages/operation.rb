require 'skyfall/cid'
require 'skyfall/collection'

module Tapfall
  class Operation
    def initialize(json)
      @json = json
    end

    def live?
      @json['live']
    end

    def did
      @json['did']
    end

    alias repo did

    def rev
      @json['rev']
    end

    def path
      @json['collection'] + '/' + @json['rkey']
    end

    def action
      @json['action'].to_sym
    end

    def collection
      @json['collection']
    end

    def rkey
      @json['rkey']
    end

    def uri
      "at://#{repo}/#{collection}/#{rkey}"
    end

    def cid
      @cid ||= @json['cid'] && Skyfall::CID.from_json(@json['cid'])
    end

    def raw_record
      @json['record']
    end

    def type
      Skyfall::Collection.short_code(collection)
    end
  end
end
