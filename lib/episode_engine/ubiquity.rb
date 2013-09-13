require 'json'
require 'google_drive'
require 'logger'
require 'net/http'
require 'open3'
require 'roo'
require 'shellwords'
require 'uri'
require 'zip'

module EpisodeEngine

  # Ubiquity integration class
  class Ubiquity




    require 'pp'
    require 'roo'
    #ENV['GOOGLE_MAIL'] = ''
    #ENV['GOOGLE_PASSWORD'] = ''

    class TranscodeSettingsLookup

      DEFAULT_TRANSCODE_SETTINGS_GOOGLE_WORKBOOK_ID = '0AkcbJWkynMREdEV2RlZFZ0kzQmtsUXNXWXpNcE5RUUE'
      DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME = 'Transcode Settings'

      class << self

        attr_writer :logger

        def logger
          @logger ||= Logger.new(STDOUT)
        end # logger

        attr_accessor :options
        attr_accessor :workbook_id

        def build_transcode_settings_table(args = { })
          args = args.dup
          #puts "BUILD TRANSCODE SETTINGS TABLE ARGS: #{PP.pp(args, '')}"
          google_workbook_id = args.delete(:google_workbook_id)
          file_path = args.delete(:file_path)

          options = args
          if google_workbook_id
            table = build_transcode_settings_table_from_google(google_workbook_id, options)
          elsif file_path
            table = build_transcode_settings_table_from_file(file_path, options)
          else
            logger.error { "Failed to Build Transcode Settings Table. Arguments: #{args}" }
            table = [ ]
          end
          table
        end # build_transcode_setting_table

        def build_transcode_settings_table_from_google(workbook_id, options = { })
          options = options.dup if options.respond_to?(:dup)
          sheet_name = options.delete(:sheet_name) { DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME }

          ss = Roo::Google.new(workbook_id, options)
          ss.default_sheet = sheet_name
          rows = ss.parse(:headers => true).drop(1)

          rows
        end # build_trawscode_settings_table_from_google

        def build_transcode_settings_table_from_file(source_file_name, options = { })
          abort "Source File Not Found. #{source_file_name}" unless File.exists?(source_file_name)

          options = options.dup if options.respond_to?(:dup)
          sheet_name = options.delete(:sheet_name) { DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME }

          # response = Roo::Spreadsheet.open(source_file_name).parse(:headers => true).drop(1)
          # Roo currently creates a row out of the column headers where the keys equal the values. We remove it if is there.
          # first_row = response.first
          # response = response.drop(1) if first_row.keys == first_row.values

          ss = Roo::Spreadsheet.open(source_file_name)
          logger.debug { "Reading Data from Source File.\n#{ss.info}" }
          ss.default_sheet = sheet_name
          rows = ss.parse#(:headers => true)
          abort 'Now Rows Were Found When Parsing the Source File.' if rows.empty?

          # Roo throws an exception of we use the :headers option when parsing so we do the work ourselves
          # roo-1.11.2/lib/roo/generic_spreadsheet.rb:476:in `each': undefined method `upto' for nil:NilClass (NoMethodError)
          first_row = rows.shift
          rows.map { |r| Hash[ first_row.zip(r) ] }
        end

        def transcode_settings_lookup(values_to_look_for, map)
          logger.debug { "Searching Map For:   #{values_to_look_for}" }
          match = nil
          map.each do |map_entry|
            logger.debug { "Searching Map Entry: #{map_entry}" }
            match_failed = nil
            values_to_look_for.each do |field_name, field_value|
              map_entry_value = map_entry[field_name]
              if map_entry_value.is_a?(String)
                map_entry_value = map_entry_value[1..-2] if map_entry_value.start_with?('"')
                field_value = field_value.to_s if field_value === true || field_value === false
              else
                if field_value.is_a?(String)
                  map_entry_value = map_entry_value.to_s
                end
              end
              #field_value = field_value.to_s.downcase
              unless map_entry_value == field_value
                logger.debug { "\tNo Match For #{field_name} : #{field_value} (#{field_value.class.name}) != #{map_entry_value} (#{map_entry_value.class.name})" }
                match_failed = true
                break
              else
                logger.debug { "\tMatch For #{field_name} : #{field_value} (#{field_value.class.name}) == #{map_entry_value} (#{map_entry_value.class.name})"  }
              end
            end
            unless match_failed
              match = map_entry
              break
            end
          end
          match
        end # transcode_settings_lookup

        def find(data, options = { })
          options = options.dup if options.respond_to?(:dup)
          @logger = options.delete(:logger) if options[:logger]

          file_path = options.delete(:file_path)

          google_workbook_id = options.delete(:google_workbook_id) { DEFAULT_TRANSCODE_SETTINGS_GOOGLE_WORKBOOK_ID }
          google_workbook_username = options.delete(:google_workbook_username)
          google_workbook_password = options.delete(:google_workbook_password)

          transcode_settings_options = { }
          transcode_settings_options[:google_workbook_id] = google_workbook_id if google_workbook_id
          transcode_settings_options[:user] = google_workbook_username
          transcode_settings_options[:password] = google_workbook_password
          transcode_settings_options[:file_path] = file_path if file_path

          #@transcode_settings_table ||= self.build_transcode_settings_table(workbook_id, options)
          @transcode_settings_table = self.build_transcode_settings_table(transcode_settings_options)
          data_to_find = { }
          data.each { |k,v| data_to_find[k.to_s] = v }
          unused_common_fields = data_to_find.keys - @transcode_settings_table.first.keys
          #puts 'Unused Common Field: '
          #pp unused_common_fields
          cm = data_to_find.delete_if { |k,_| unused_common_fields.include?(k) }
          #puts "Data to match:"
          #pp cm
          record = self.transcode_settings_lookup(cm, @transcode_settings_table) || { }
          record
        end

      end # self

    end # TranscodeSettingsLookup


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

    class HTTP < Submitter

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
      method = options[:method] || :http
      if method == :http
        _response = Ubiquity::HTTP.submit(workflow)
        response_as_hash = Ubiquity::HTTP.response_to_hash(_response)
      else
        _response = Ubiquity::CommandLine.submit(workflow)
        response_as_hash = Ubiquity::CommandLine.response_to_hash(_response)
      end
      response_as_hash
    end # self.submit_workflow

    def self.submit(args = { }, options = { })
      logger.debug { "Submission Arguments: #{PP.pp(args, '')}" }
      #method = _params['method'] || :command_line

      submission_method = args['method'] || :http

      workflow_parameters_json = args['workflow_parameters'] || args['workflow-parameters']
      workflow_parameters = JSON.parse(workflow_parameters_json) if workflow_parameters_json.is_a?(String)
      workflow_parameters ||= { }
      source_file_path = workflow_parameters['source_file_path']

      source_file_path ||= args['source_file_path']
      logger.debug { "Source File Path: #{source_file_path}" }

      responses = { }

      transcode_settings_lookup_options = {
        :google_workbook_username => options[:google_workbook_username],
        :google_workbook_password => options[:google_workbook_password],
        :google_workbook_id => options[:google_workbook_id]
      }

      [*source_file_path].each do |sfp|

        # Execute MIG
        metadata_sources = mig(sfp, :executable_path => options[:mig_executable_file_path])

        # Determine Epitask(s)
        TranscodeSettingsLookup.logger = logger
        transcode_settings = TranscodeSettingsLookup.find(metadata_sources['common'], transcode_settings_lookup_options)
        logger.debug { "Transcode Settings: #{transcode_settings}" }

        workflow_parameters['source_file_path'] = sfp
        #workflow_parameters['metadata_sources'] = metadata_sources

        unless transcode_settings

          # No Match - Transcode Settings Were Not Found
          workflow_name = options[:submission_missing_lookup_workflow_name] || DEFAULT_TRANSCODE_SETTINGS_NOT_FOUND_WORKFLOW_NAME

          workflow = {'workflow_name' => workflow_name, 'workflow_parameters' => JSON.generate(workflow_parameters)}
          submission_options = { :method => submission_method}
          response_as_hash = submit_workflow(workflow, submission_options)

          return { :error => { :message => 'Transcode Settings Not Found' } }
        end

        workflow_name = args['workflow_name'] || options[:submission_workflow_name] || DEFAULT_WORKFLOW_NAME
        fields_to_split = [ 'epitask_file_name_source_directory', 'epitask_file_name', 'encoded_file_name_suffix' ]

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

          #_params['workflow_name'] ||= 'EPISODE_ENGINE_SUBMISSION'
          #_params['workflow_parameters'] ||= JSON.generate({:source_file_path => _params['source_file_path']})

          #workflow['workflow_parameters'] ||= JSON.generate({:source_file_path => sfp})

          workflow = { 'workflow_name' => workflow_name, 'workflow_parameters' => JSON.generate(workflow_parameters) }
          submission_options = { :method => submission_method}
          response_as_hash = submit_workflow(workflow, submission_options)

          task_responses[task] = response_as_hash
        end
        responses[sfp] = task_responses
      end
      logger.debug { "Ubiquity Submit Responding With: #{responses}"}
      responses
    end # self.submit

  end # Ubiquity

end # EpisodeEngine