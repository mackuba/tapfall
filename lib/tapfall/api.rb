require 'json'
require 'net/http'
require 'uri'

module Tapfall
  class API
    def initialize(server, options = {})
      @root_url = build_root_url(server)
      @options = options
    end

    def add_repo(did)
      add_repos([did])
    end

    def add_repos(dids)
      post_request('/repos/add', { dids: dids })
    end

    def remove_repo(did)
      remove_repos([did])
    end

    def remove_repos(dids)
      post_request('/repos/remove', { dids: dids })
    end

    def resolve_did(did)
      get_request("/resolve/#{did}")
    end

    private

    def build_root_url(server)
      if !server.is_a?(String)
        raise ArgumentError, "Server parameter should be a string"
      end

      if server.include?('://')
        uri = URI(server)

        if uri.scheme != 'http' && uri.scheme != 'https'
          raise ArgumentError, "Server parameter should be a hostname or a http:// or https:// URL"
        elsif uri.path != ''
          raise ArgumentError, "Server URL should only include a hostname, without path"
        end

        uri.to_s
      else
        server = "https://#{server}"
        uri = URI(server) # raises if invalid
        server
      end
    end

    def get_request(path)
      uri = URI(@root_url + path)

      request = Net::HTTP::Get.new(uri)

      if @options[:admin_password]
        request.basic_auth('admin', @options[:admin_password])
      end

      response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => (uri.scheme == 'https')) do |http|
        http.request(request)
      end

      handle_response(response)
    end

    def post_request(path, json_data)
      uri = URI(@root_url + path)

      request = Net::HTTP::Post.new(uri)
      request.body = JSON.generate(json_data)
      request.content_type = "application/json"

      if @options[:admin_password]
        request.basic_auth('admin', @options[:admin_password])
      end

      response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => (uri.scheme == 'https')) do |http|
        http.request(request)
      end

      handle_response(response)
    end

    def handle_response(response)
      status = response.code.to_i
      message = response.message
      response_body = (response.content_type == 'application/json') ? JSON.parse(response.body) : response.body

      if response.is_a?(Net::HTTPSuccess)
        response_body
      else
        raise BadResponseError.new(status, message, response_body)
      end
    end
  end
end
