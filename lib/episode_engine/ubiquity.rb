require 'open3'
require 'shellwords'

require 'net/http'
require 'uri'

require 'json'
require 'logger'

module EpisodeEngine

  # Ubiquity integration class
  class Ubiquity

    class Submitter

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

    end # Submitter


    class CommandLine < Submitter

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

        arguments = [ @executable_path, 'job' ]
        arguments << '--workflow' << workflow_name if workflow_name
        arguments << '--workflow-parameters' << workflow_parameters if workflow_parameters
        cmd_line = arguments.shelljoin
        system_response = execute(cmd_line)

        response = { :command_line => cmd_line, :response => system_response }
        response
      end # submit

    end # CommandLIne

    class HTTP < Submitter

      DEFAULT_HOST_ADDRESS = 'localhost'
      DEFAULT_HOST_PORT = '80'
      DEFAULT_URI_PATH = 'job'

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
        response = { :uri => @job_uri, :response => r }
        response
      end # submit

    end # HTTP

  end # Ubiquity

end # EpisodeEngine