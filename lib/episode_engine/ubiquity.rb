require 'json'
require 'logger'
require 'open3'
require 'shellwords'
require 'uri'

require 'episode_engine/ubiquity/submitter'
require 'episode_engine/ubiquity/submission_manager'
require 'episode_engine/ubiquity/transcode_settings_lookup'

module EpisodeEngine

  # Ubiquity integration module
  module Ubiquity

    #ENV['GOOGLE_MAIL'] = ''
    #ENV['GOOGLE_PASSWORD'] = ''

    DEFAULT_WORKFLOW_NAME = 'EPISODE_ENGINE_SUBMISSION'
    DEFAULT_TRANSCODE_SETTINGS_NOT_FOUND_WORKFLOW_NAME = 'EPISODE_ENGINE_SUBMISSION_TRANSCODE_SETTINGS_NOT_FOUND'
    DEFAULT_MIG_EXECUTABLE_PATH = '/Library/Scripts/ubiquity/media_processing_tool/bin/mig'

    class <<self
      attr_accessor :logger

    end # self

    # @param [String] cmd_line The command line to execute
    # @return [Hash] { :stdout => [String], :stderr => [String], :status => [Object], :success => [Boolean] }
    def self.execute(cmd_line)
      begin
        stdout_str, stderr_str, status = Open3.capture3(cmd_line)
        logger.error "Error Executing #{cmd_line}. Stdout: #{stdout_str} Stderr: #{stderr_str}" unless status.success?
        return { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => status.success? }
      rescue
        logger.error { "Error Executing '#{cmd_line}'. Exception: #{$!} @ #{$@} STDOUT: '#{stdout_str}' STDERR: '#{stderr_str}' Status: #{status.inspect}" }
        return { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => false }
      end
    end # execute

    def self.mig(file_path, options = { })
      raise Errno::ENOENT, "File Not Found. File Path: '#{file_path}'" unless File.exist?(file_path)

      executable_path = options[:executable_path] || options[:mig_executable_file_path] || DEFAULT_MIG_EXECUTABLE_PATH
      raise Errno::ENOENT, "Executable File Path Not Found. File Path: '#{executable_path}'" unless File.exist?(executable_path)

      command_line = [ executable_path, file_path ].shelljoin
      response = execute(command_line)
      logger.debug { "Response from MIG:\n\tSTATUS: #{response[:status]}\n\tSTDOUT: #{response[:stdout]}\n\tSTDERR: #{response[:stderr]}" }
      return response unless response[:status]
      metadata_sources = JSON.parse(response[:stdout])
      metadata_sources
    end # self.mig


    def self.submit_workflow(workflow, options = { })
      logger.debug { "Submitting To Ubiquity: #{PP.pp(workflow, '')}"}
      _response = Submitter.submit(options.merge(workflow))
      response_as_hash = Submitter.response_as_hash
      logger.debug { "Response From Ubiquity:\n\n#{_response}\n\n#{PP.pp(response_as_hash, '')}"}
      response_as_hash
    end # self.submit_workflow

    def self.lookup_transcode_settings(values_to_lookup, options = { })
      TranscodeSettingsLookup.find(values_to_lookup, options)
    end # self.lookup_transcode_settings

    def self.submit_source_file_path(source_file_path, workflow_name, workflow_arguments, options)
      workflow_arguments['source_file_path'] = source_file_path

      submission_method = options[:submission_method] || :http
      # Execute MIG
      metadata_sources = mig(source_file_path, :executable_path => options[:mig_executable_file_path])

      # Determine Epitask(s)
      transcode_settings_lookup_options = options[:transcode_settings_lookup]
      transcode_settings = lookup_transcode_settings(metadata_sources['common'], transcode_settings_lookup_options)
      logger.debug { "Transcode Settings: #{transcode_settings}" }

      #workflow_parameters['metadata_sources'] = metadata_sources

      if transcode_settings.empty?

        # No Match - Transcode Settings Were Not Found
        workflow_name = options[:submission_missing_lookup_workflow_name] || DEFAULT_TRANSCODE_SETTINGS_NOT_FOUND_WORKFLOW_NAME

        workflow = {'workflow_name' => workflow_name, 'workflow_parameters' => JSON.generate(workflow_arguments)}
        submission_options = { :method => submission_method}
        response_as_hash = submit_workflow(workflow, submission_options)

        return { :error => { :message => 'Transcode Settings Not Found' }, :metadata_sources => metadata_sources, :ubiquity_submission => response_as_hash }
      end
      workflow_arguments = transcode_settings.merge(workflow_arguments)

      fields_to_split = [ 'epitask_file_name', 'encoded_file_name_suffix' ]

      splits = { }
      fields_to_split.each do |field_name|
        field_values = transcode_settings[field_name]
        splits[field_name] = field_values ? field_values.split(',').map { |v| v.respond_to?(:strip) ? v.strip : v } : [ ]
      end

      tasks = splits.delete('epitask_file_name')
      logger.debug { "Tasks: #{tasks}"}

      task_responses = { }
      tasks.each do |task|

        workflow_arguments['epitask_file_name'] = task
        splits.each { |k,v| workflow_arguments[k] = v.shift }

        workflow = { 'workflow_name' => workflow_name, 'workflow_parameters' => JSON.generate(workflow_arguments) }
        submission_options = { :method => submission_method}
        response_as_hash = submit_workflow(workflow, submission_options)

        task_responses[task] = response_as_hash
      end
      { :tasks => task_responses, :metadata_sources => metadata_sources }
    end # self.process_source_file_path

    # @param [Hash] args The parameters from the request
    # @option args [String] workflow_name
    # @option args [String] workflow_arguments
    # @param [Hash] options Options for this request
    # @option options [Symbol] :submission_method
    # @option options [String] :submission_workflow_name
    # @option options [String] :google_workbook_username
    # @option options [String] :google_workbook_password
    # @option options [String] :google_workbook_id
    def self.submit(args = { }, options = { })
      args = args.dup
      options = options.dup

      logger.debug { "Submission Arguments: #{PP.pp(args, '')}" }
      #method = _params['method'] || :command_line

      workflow_name = search_hash!(args, :workflow_name, { :ignore_strings => %w(_ -), :case_sensitive => false })
      workflow_name ||= options[:submission_workflow_name] || DEFAULT_WORKFLOW_NAME

      workflow_arguments_json = search_hash!(args, :workflow_arguments, :workflow_parameters, { :ignore_strings => %w(_ -), :case_sensitive => false })
      workflow_arguments = JSON.parse(workflow_arguments_json) if workflow_arguments_json.is_a?(String)
      workflow_arguments ||= { }

      source_file_path = search_hash!(args, :source_file_path, { :ignore_strings => %w(_ -), :case_sensitive => false })
      source_file_path ||= search_hash!(workflow_arguments, :source_file_path, { :ignore_strings => %w(_ -), :case_sensitive => false })
      logger.debug { "Source File Path: #{source_file_path}" }

      args.each { |k, v| workflow_arguments[k] = v }

      #options[:submission_method] = args['method'] || :command_line
      options[:submission_method] = args['method'] || :http

      options[:transcode_settings_lookup] = {
        :google_workbook_username => options[:google_workbook_username],
        :google_workbook_password => options[:google_workbook_password],
        :google_workbook_id => options[:google_workbook_id]
      }
      TranscodeSettingsLookup.logger = logger

      # Submit each source file path separately and record it's response separately
      responses = { }
      [*source_file_path].each do |sfp|
        response = self.submit_source_file_path(source_file_path, workflow_name, workflow_arguments, options)
        responses[sfp] = response
      end

      logger.debug { "Ubiquity Submit Responding With: #{responses}"}
      responses
    end # self.submit

  end # Ubiquity

end # EpisodeEngine