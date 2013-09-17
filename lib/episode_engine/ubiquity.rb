require 'json'
require 'logger'
require 'open3'
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
    DEFAULT_MIG_EXECUTABLE_PATH = '/Users/admin/work/media_processing_tool/bin/mig'

    class <<self
      attr_accessor :logger
    end # self

    def self.mig(file_path, options = { })
      executable_path = options[:executable_path] || DEFAULT_MIG_EXECUTABLE_PATH
      command_line = "#{executable_path} #{file_path}"
      _stdout, _stderr, _status = Open3.capture3(command_line)
      logger.debug { "Response from MIG:\n\tSTATUS: #{_status}\n\tSTDOUT: #{_stdout}\n\tSTDERR: #{_stderr}" }
      metadata_sources = JSON.parse(_stdout)
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

    def self.submit_source_file_path(source_file_path, workflow_name, workflow_parameters, options)
      workflow_parameters['source_file_path'] = source_file_path

      submission_method = options[:submission_method] || :http
      # Execute MIG
      metadata_sources = mig(source_file_path, :executable_path => options[:mig_executable_file_path])

      # Determine Epitask(s)
      transcode_settings_lookup_options = options[:transcode_settings_lookup]
      transcode_settings = lookup_transcode_settings(metadata_sources['common'], transcode_settings_lookup_options)
      logger.debug { "Transcode Settings: #{transcode_settings}" }

      #workflow_parameters['metadata_sources'] = metadata_sources

      unless transcode_settings

        # No Match - Transcode Settings Were Not Found
        workflow_name = options[:submission_missing_lookup_workflow_name] || DEFAULT_TRANSCODE_SETTINGS_NOT_FOUND_WORKFLOW_NAME

        workflow = {'workflow_name' => workflow_name, 'workflow_parameters' => JSON.generate(workflow_parameters)}
        submission_options = { :method => submission_method}
        response_as_hash = submit_workflow(workflow, submission_options)

        return { :error => { :message => 'Transcode Settings Not Found' } }
      end
      workflow_parameters = transcode_settings.merge(workflow_parameters)

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

        workflow_parameters['epitask_file_name'] = task
        splits.each { |k,v| workflow_parameters[k] = v.shift }

        workflow = { 'workflow_name' => workflow_name, 'workflow_parameters' => JSON.generate(workflow_parameters) }
        submission_options = { :method => submission_method}
        response_as_hash = submit_workflow(workflow, submission_options)

        task_responses[task] = response_as_hash
      end
      task_responses
    end # self.process_source_file_path

    # @param [Hash] args The parameters from the request
    # @option args [String] workflow-name
    # @option args [String] workflow-arguments
    # @param [Hash] options Options for this request
    # @option options [Symbol] :submission_method
    # @option options [String] :submission_workflow_name
    # @option options [String] :google_workbook_username
    # @option options [String] :google_workbook_password
    # @option options [String] :google_workbook_id
    def self.submit(args = { }, options = { })
      logger.debug { "Submission Arguments: #{PP.pp(args, '')}" }
      #method = _params['method'] || :command_line

      workflow_name = args['workflow_name'] || args['workflow-name'] || options[:submission_workflow_name] || DEFAULT_WORKFLOW_NAME

      workflow_parameters_json = args['workflow-arguments'] || args['workflow_arguments'] || args['workflow_parameters'] || args['workflow-parameters']
      workflow_parameters = JSON.parse(workflow_parameters_json) if workflow_parameters_json.is_a?(String)
      workflow_parameters ||= { }
      source_file_path = workflow_parameters['source_file_path'] || workflow_parameters['source-file-path']

      source_file_path ||= args['source_file_path'] || args['source-file-path']
      logger.debug { "Source File Path: #{source_file_path}" }


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
        response = self.submit_source_file_path(source_file_path, workflow_name, workflow_parameters, options)
        responses[sfp] = response
      end

      logger.debug { "Ubiquity Submit Responding With: #{responses}"}
      responses
    end # self.submit

  end # Ubiquity

end # EpisodeEngine