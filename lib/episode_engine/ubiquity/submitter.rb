require 'episode_engine/ubiquity/submitter/cli'
require 'episode_engine/ubiquity/submitter/http'
module EpisodeEngine

  module Ubiquity

    class Submitter

      class << self
        attr_reader :last_method
        attr_reader :response
      end # self

      def self.submit(args = { })
        @response = @last_method = nil
        args = args.dup

        method = args.delete(:method) { :http }
        @last_method = method.to_sym

        case @last_method
        when :http
          @response = Ubiquity::Submitter::HTTP.submit(args)
        when :command_line
          @response = Ubiquity::Submitter::CommandLine.submit(args)
        else
          # Throw an error
        end
        @response
      end # self.submit

      def self.response_as_hash(response = @response, method = @last_method)
        case method
        when :http
          response = Ubiquity::Submitter::HTTP.response_to_hash(response)
        when :command_line
          response = Ubiquity::Submitter::CommandLine.response_as_hash(response)
        else
          response = { }
        end
        response
      end # self.response_as_hash

    end # Submitter

  end # Ubiquity

end # Episode Engine