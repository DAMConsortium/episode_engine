require 'open3'
require 'shellwords'

require 'episode_engine/ubiquity/submitter/common'

module EpisodeEngine

  module Ubiquity

    class Submitter

      class CommandLine < Common

        DEFAULT_EXECUTABLE_PATH = '/usr/local/bin/uu'
        #DEFAULT_EXECUTABLE_PATH = '/usr/local/ubiquity/lib/udam_utils/uu'

        attr_accessor :executable_path

        def initialize(args = {})
          super(args)
          @executable_path = args[:executable_path] || DEFAULT_EXECUTABLE_PATH

        end # initialize

        # @param [String] cmd_line The command line to execute
        # @return [Hash] { "STDOUT" => [String], "STDERR" => [String], "STATUS" => [Object] }
        def execute(cmd_line)
          begin
            stdout_str, stderr_str, status = Open3.capture3(cmd_line)
            logger.error "Error Executing #{cmd_line}. Stdout: #{stdout_str} Stderr: #{stderr_str}" unless status.success?
            return { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => status.success? }
          rescue
            logger.error { "Error Executing '#{cmd_line}'. Exception: #{$!} @ #{$@} STDOUT: '#{stdout_str}' STDERR: '#{stderr_str}' Status: #{status.inspect}" }
            return { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => false }
          end
        end # execute

        def submit(args = {})
          params = common_submit(args)

          workflow_name = params[:workflow_name]
          workflow_parameters = params[:workflow_parameters]

          arguments = [ @executable_path, 'jobs' ]
          arguments << '--workflow' << workflow_name if workflow_name
          arguments << '--workflow-parameters' << workflow_parameters if workflow_parameters
          cmd_line = arguments.shelljoin
          system_response = execute(cmd_line)

          response = { :command_line => cmd_line, :response => system_response }
          response
        end # submit

        def self.response_as_hash(response)
          response = response.dup
          success = response[:response]['success']
          response[:job_id] = success ? response[:response][:stdout] : nil
          response
        end

      end # CommandLIne

    end # Submitter

  end # Ubiquity

end # EpisodeEngine