require 'net/http'

require 'episode_engine/ubiquity/submitter/common'

module EpisodeEngine

  module Ubiquity

    class Submitter

      class HTTP < Common

        DEFAULT_HOST_ADDRESS = 'localhost'
        DEFAULT_HOST_PORT = 4567
        DEFAULT_URI_PATH = 'jobs'

        attr_accessor :host_address
        attr_accessor :host_port

        # @param [Hash] args
        # @option args [String] :host_address
        # @option args [String, Integer] :host_port
        def initialize(args = {})
          super(args)
          host_address = args[:host_address] || DEFAULT_HOST_ADDRESS
          host_port = args[:host_port] || DEFAULT_HOST_PORT
          path = args[:path] || DEFAULT_URI_PATH
          path = path[1..-1] if path.is_a?(String) and path.start_with?('/')
          @job_uri = URI.parse("http://#{host_address}:#{host_port}/#{path}")
        end # initialize

        def submit(args = {})
          params = common_submit(args)

          r = Net::HTTP.post_form(@job_uri, params)
          response = { :uri => @job_uri.to_s, :response => r }
          if r.body
            response[:body] = r.body
            if r.content_type == 'application/json'
              response[:body_as_hash] = JSON.parse(r.body)
            else
              response[:body_as_hash] = { }
            end
          end
          response
        end # submit

        def self.response_to_hash(response)
          out = response
          _response = out.delete(:response)
          out[:code] = _response.code
          out[:message] = _response.message
          out[:content_type] = _response.content_type

          _r = out[:body_as_hash]['response'] || { }
          out[:job_id] = _r['stdout']
          out[:success] = _r['success']
          out
        end # self.response_to_hash

      end # HTTP

    end # Submitter

  end # Ubiquity

end # EpisodeEngine