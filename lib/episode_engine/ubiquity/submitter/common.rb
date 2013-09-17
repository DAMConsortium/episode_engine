require 'json'

module EpisodeEngine

  module Ubiquity

    class Submitter

      class Common

        attr_accessor :logger

        def self.submit(args = {})
          new(args).submit(args)
        end # self.submit

        def initialize(args = {})
          @logger = args[:logger] || Logger.new(args[:log_to] || STDERR)
          logger.level = args[:log_level] if args[:log_level]
        end # initialize

        def common_submit(args = {})
          params = { }
          params[:workflow_name] = args[:workflow_name] || args['workflow_name'] || args['workflow-name']
          params[:workflow_parameters] = args[:workflow_parameters] || args['workflow_parameters'] || args['workflow-parameters']
          params
        end # submit

      end # Common

    end # Submitter

  end # Ubiquity

end # EpisodeEngine