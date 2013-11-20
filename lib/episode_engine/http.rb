require 'time'
require 'json'
require 'pp'

require 'sinatra/base'
#require 'sinatra/contrib'
require 'xmlsimple'

require 'poller'
require 'episode_engine'
require 'episode_engine/api/adapters/xmlrpc'
require 'episode_engine/database'
require 'episode_engine/date_time_helper'
require 'episode_engine/ubiquity'
require 'episode_engine/status_tracker'

module EpisodeEngine

  class HTTP < Sinatra::Base

    # Just a short cut to the Database::DEFAULT_DATABASE_NAME
    DEFAULT_DATABASE_NAME = Database::DEFAULT_DATABASE_NAME

    configure :development do
      #enable :logging
      #register Sinatra::Reloader
    end

    ## ROUTES BEGIN ####################################################################################################
    #load('episode_engine/http/routes.rb')
    require 'episode_engine/http/routes'
    ## ROUTES END ######################################################################################################

    def format_response(response, args = { })
      supported_types = [ 'application/json', 'application/xml', 'text/xml' ]
      case request.preferred_type(supported_types)
        when 'application/json'
          content_type :json
          _response = response.is_a?(Hash) || response.is_a?(Array) ? JSON.generate(response) : response
        #when 'application/xml', 'text/xml'
        #  content_type :xml
        #  _response = XmlSimple.xml_out(response, { :root_name => 'response' })
        else
          content_type :json
          _response = response.is_a?(Hash) || response.is_a?(Array) ? JSON.generate(response) : response
      end
       _response
    end # output_response

    def parse_body
      if request.media_type == 'application/json'
        request.body.rewind
        body_contents = request.body.read
        logger.debug { "Parsing: '#{body_contents}'" }
        if body_contents
          json_params = JSON.parse(body_contents)
          return json_params
        end
      end

    end # parse_body

    # Will try to convert a body to parameters and merge them into the params hash
    # Params will override the body parameters
    #
    # @params [Hash] _params (params) The parameters parsed from the query and form fields
    def merge_params_from_body(_params = params)
      _params = _params.dup
      _params_from_body = parse_body
      _params = _params_from_body.merge(_params) if _params_from_body.is_a?(Hash)
      indifferent_hash.merge(_params)
    end # merge_params_from_body


    def request_to_hash(_request = request)
      #request.accept              # ['text/html', '*/*']
      #request.accept? 'text/xml'  # true
      #request.preferred_type(t)   # 'text/html'
      #request.body                # request body sent by the client (see below)
      #request.scheme              # "http"
      #request.script_name         # "/example"
      #request.path_info           # "/foo"
      #request.port                # 80
      #request.request_method      # "GET"
      #request.query_string        # ""
      #request.content_length      # length of request.body
      #request.media_type          # media type of request.body
      #request.host                # "example.com"
      #request.get?                # true (similar methods for other verbs)
      #request.form_data?          # false
      #request["some_param"]       # value of some_param parameter. [] is a shortcut to the params hash.
      #request.referrer            # the referrer of the client or '/'
      #request.user_agent          # user agent (used by :agent condition)
      #request.cookies             # hash of browser cookies
      #request.xhr?                # is this an ajax request?
      #request.url                 # "http://example.com/example/foo"
      #request.path                # "/example/foo"
      #request.ip                  # client IP address
      #request.secure?             # false (would be true over ssl)
      #request.forwarded?          # true (if running behind a reverse proxy)
      #request.env                 # raw env hash handed in by Rack
      out = { }
      [
        :request_method, :url, :host, :path, :script_name, :query_string,
        :xhr?, :ip, :user_agent, :cookies, :media_type, :params,
      ].each { |method_name| out[method_name] = _request.send(method_name) }
      #out[:env] = request['env'].map { |entry| entry.to_s }
      out[:accept] = _request.accept.map { |entry| entry.to_s }
      out[:preferred_type] = request.preferred_type.to_s
      body = _request.body
      out[:body] = body ? body.dup.read : ''
      out
    end # request_to_hash

    # @param [Hash] args
    # @option args [Request] :request
    def request_to_s(args = { })
      _request = args[:request] || request
      output = <<-OUTPUT
------------------------------------------------------------------------------------------------------------------------
    REQUEST
    Method:         #{_request.request_method}
    URI:            #{_request.url}

    Host:           #{_request.host}
    Path:           #{_request.path}
    Script Name:    #{_request.script_name}
    Query String:   #{_request.query_string}
    XHR?            #{_request.xhr?}


    Remote
    Host:           #{_request.env['REMOTE_HOST']}
    IP:             #{_request.ip}
    User Agent:     #{_request.user_agent}
    Cookies:        #{_request.cookies}
    Accepts:        #{_request.accept}
    Preferred Type: #{_request.preferred_type}

    Media Type:     #{_request.media_type}
    BODY BEGIN:
#{_request.body.read}
    BODY END.

    Parsed Parameters:
    #{PP.pp(_request.params, '', 60)}

------------------------------------------------------------------------------------------------------------------------
      OUTPUT
      _request.body.rewind
      output
    end # request_to_s

    def log_request(route = '')
      return if request.path == '/favicon.ico'
      logger.debug { "\n#{request_to_s}" }
      #puts requests.insert(request_to_hash)
    end # log_request

    def log_request_match(route)
      logger.debug { "MATCHED: #{request.url} -> #{route}\nParsed Parameters: #{params}" }
    end # log_request_match

    def record_request(subject, system = nil, route = nil)
      request_as_hash = request_to_hash
      request_as_hash['route'] = route.to_s
      request_as_hash['system'] = system.to_s
      id = Database::Helpers::Requests.insert(request_as_hash, subject, system)
      id
    end # record_request

    def submitter(_params = params)
      _params = _params.dup
      submitter_ip = request.ip
      submitter_host = request.env['REMOTE_HOST']
      submitter_address = submitter_host || submitter_ip

      submitter_id = search_hash!(_params, :submitter_id, { :ignore_strings => %w(_ -), :case_sensitive => false })
      submitter_id ||= submitter_address

      _submitter = { }
      _submitter[:submitter_ip] = submitter_ip
      _submitter[:submitter_host] = submitter_host
      _submitter[:submitter_address] = submitter_address
      _submitter[:submitter_id] = submitter_id
      _submitter
    end # submitter

    def get_ubiquity_job_status(job_id)
      #@sm ||= EpisodeEngine::Ubiquity::SubmissionManager.new
      #@sm.submission_get_by_ubiquity_job_id(job_id).first
    end # get_ubiquity_job_status

    def process_ubiquity_job_status_request(_request)
      out = { }
      logger.debug { "JSR: #{PP.pp(_request, '')}" }

      _response = search_hash(_request, :response)
      source_file_paths = search_hash(_response, :content)
      source_file_paths.each do |source_file_path, data|
        tasks = data[:tasks]
        task_responses = { }

        tasks.each do |task_name, task|

          job_id = task[:job_id]

          submission = get_ubiquity_job_status(job_id)

          if submission
            episode_parent_id = submission['_id']
            episode_host = submission['host']
            episode_job_status = episode_api.status_tasks('host' => episode_host, 'parent-id' => episode_parent_id) if episode_parent_id
          else
            episode_job_status = { }
          end
          task_responses[task_name] = { :ubiquity_submission => submission, :episode_submission => episode_job_status }

        end
        out[source_file_path] = task_responses
      end
      return out
    end # ubiquity_request_status

    def episode_api(_params = nil)
      return default_episode_api unless _params

      host_address = search_hash!(_params, :host_address, { :ignore_strings => %w(_ -), :case_sensitive => false })
      host_port = search_hash!(_params, :host_port, { :ignore_strings => %w(_ -), :case_sensitive => false })

      if host_address || host_port
        api_params = { }
        api_params[:host_address] = host_address if host_address
        api_params[:host_port] = host_port if host_port
        api = self.initialize_api(api_params)
      else
        api = default_episode_api
      end
      api
    end # episode_api

    def self.initialize_db(args = {})
      EpisodeEngine::Database::Mongo.new(args)
    end # set_initialize_db

    def self.initialize_logger(args = {})
      logger = Logger.new(args[:log_to] || STDOUT)
      logger.level = args[:log_level] if args[:log_level]
      logger
    end # self.initialize_logger

    def self.initialize_api(args = {})
      EpisodeEngine::API::Adapters::XMLRPC.new(args)
    end # self.initialize_api

    def self.process_transcode_settings_lookup_options!(options = { })
      workbook_username = search_hash!(options, :transcode_settings_google_workbook_username, :google_workbook_username)
      workbook_password = search_hash!(options, :transcode_settings_google_workbook_password, :google_workbook_password)
      google_workbook_id = search_hash!(options, :transcode_settings_google_workbook_id, :google_workbook_id) # || Ubiquity::TranscodeSettingsLookup::DEFAULT_TRANSCODE_SETTINGS_GOOGLE_WORKBOOK_ID
      workbook_file_path = search_hash!(options, :transcode_settings_workbook_file_path, :workbook_file_path)
      workbook_sheet_name = search_hash!(options, :transcode_settings_workbook_sheet_name, :workbook_sheet_name) # || Ubiquity::TranscodeSettingsLookup::DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME
      transcode_settings_lookup_options = { }
      transcode_settings_lookup_options[:google_workbook_username] = workbook_username if workbook_username
      transcode_settings_lookup_options[:google_workbook_password] = workbook_password  if workbook_password
      transcode_settings_lookup_options[:google_workbook_id] = google_workbook_id if google_workbook_id
      transcode_settings_lookup_options[:workbook_file_path] = workbook_file_path if workbook_file_path
      transcode_settings_lookup_options[:sheet_name] = workbook_sheet_name if workbook_sheet_name
      transcode_settings_lookup_options
    end # process_transcode_settings_lookup_options!

    def self.process_transcode_settings_lookup_options(options = { })
      self.process_transcode_settings_lookup_options!(options.dup)
    end # process_transcode_settings_lookup_options

    def self.initialize_ubiquity(args = {})
      logger = args[:logger]
      Ubiquity.logger = logger
      Ubiquity::TranscodeSettingsLookup.logger = logger

      ubiquity_submission_method = args[:ubiquity_submission_method]

      ubiquity_executable_path = args[:ubiquity_executable_path]
      ubiquity_submission_workflow_name = args[:ubiquity_submission_workflow_name] || Ubiquity::DEFAULT_WORKFLOW_NAME
      ubiquity_submission_missing_lookup_workflow_name = args[:ubiquity_submission_missing_lookup_workflow_name] || Ubiquity::DEFAULT_TRANSCODE_SETTINGS_NOT_FOUND_WORKFLOW_NAME

      mig_executable_file_path = args[:mig_executable_file_path] || Ubiquity::DEFAULT_MIG_EXECUTABLE_PATH

      transcode_settings_lookup_options = process_transcode_settings_lookup_options!(args)

      ubiquity_options = {
        :submission_workflow_name => ubiquity_submission_workflow_name,
        :submission_missing_lookup_workflow_name => ubiquity_submission_missing_lookup_workflow_name,
        :mig_executable_file_path => mig_executable_file_path,
        :transcode_settings_lookup => transcode_settings_lookup_options,
      }
      ubiquity_options
    end # self.initialize_ubiquity

    def self.initialize_status_tracker(args = { })
      args[:logger] ||= settings.logger

      status_tracker_args = { }
      status_tracker_args[:logger] = args[:logger]
      status_tracker_args[:requests] = args.delete(:requests)
      status_tracker_args[:jobs] = args.delete(:jobs)

      status_tracker = Ubiquity::StatusTracker.new(status_tracker_args)
      #return status_tracker

      poller_args = { }
      poller_args[:logger] = args[:logger]
      poller_args[:poll_interval] = args[:poll_interval] || 15
      poller_args[:worker] = status_tracker
      status_tracker_poller = Poller.new(poller_args)
      @status_tracker_thread = Thread.new { status_tracker_poller.start }

    end # initialize_status_tracker

    # @param [Hash] args
    # @option args [Logger] :logger
    # @option args [String] :binding
    # @option args [String] :local_port
    def self.init(args = {})
      set(:bind, args.delete(:binding))
      set(:port, args.delete(:local_port))
      set(:initial_options, args)

      logger = initialize_logger(args)
      set(:logger, logger)
      args[:logger] = logger

      db = initialize_db(args)
      set(:db, db)


      requests = Database::Helpers::Requests
      requests.db = db
      set(:requests, requests)

      jobs = Database::Helpers::Jobs
      jobs.db = db
      set(:jobs, jobs)

      api = initialize_api(args)
      set(:default_episode_api, api)

      args[:db] = db

      ubiquity_options = initialize_ubiquity(args)
      set(:ubiquity_options, ubiquity_options)

      ubiquity_db = Ubiquity::Database.new(ubiquity_options)
      set(:ubiquity_db, ubiquity_db)

      ubiquity_jobs = Ubiquity::Database::Helpers::Jobs
      ubiquity_jobs.db = ubiquity_db
      set(:ubiquity_jobs, ubiquity_jobs)
      abort('Setting for "Ubiquity Jobs" is undefined.') unless settings.ubiquity_jobs

      status_tracker = initialize_status_tracker(args.merge(:requests => requests, :jobs => ubiquity_jobs))
      set(:status_tracker, status_tracker)

    end # self.init


    def self.run!(*)
      super

      # Start Status Tracker Poller
      #@status_tracker_thread = Thread.new { status_tracker_poller.start }

    end

    #
    attr_accessor :logger

    #
    attr_accessor :db

    #
    attr_accessor :requests

    #
    attr_accessor :default_episode_api

    #
    attr_accessor :status_tracker

    ## @param [Hash] args
    ## @option args [Logger] :logger
    ## @option args [String] :log_to
    ## @option args [Integer] :log_level
    def initialize(args = {})
      @logger = self.class.logger
      logger.debug { 'Initializing Episode Engine HTTP Application' }

      @db = self.class.db

      @default_episode_api = self.class.default_episode_api

      @status_tracker = self.class.status_tracker
      super
    end # initialize

  end # HTTP

end # EpisodeEngine

