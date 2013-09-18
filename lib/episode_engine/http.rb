require 'json'
require 'pp'
require 'sinatra/base'
#require 'sinatra/contrib'
require 'xmlsimple'
require 'episode_engine'
require 'episode_engine/api/adapters/xmlrpc'
require 'episode_engine/database'
require 'episode_engine/ubiquity'
require 'episode_engine/poller'

module EpisodeEngine

  class HTTP < Sinatra::Base

    class Jobs

    end # Jobs

    class Requests

      METHOD_TO_ACTION = { 'POST' => :create, 'PUT' => :update, 'DELETE' => :delete, 'GET' => :retrieve }
      class << self

        attr_accessor :db

        def insert(request_detail, subject = nil, system = :episode)
          record = { }
          record[:type] = 'request'
          record[:subject] = subject
          record[:system] = system
          record[:action] = METHOD_TO_ACTION[request_detail[:request_method]]
          record[:status] = 'new'
          record[:content] = request_detail

          record[:created_at] =
          record[:modified_at] = Time.now.to_i

          id = db.insert(record)
          id
        end # insert

        def update(id, data, options = { })
          data[:modified_at] = Time.now.to_i
          query = options[:query] || {'_id' => id }

          unless data.has_key?('_id')
            data = { '$set' => data }
          end

          db.update(query, data)
        end # update

        def find_by_id(id)
          db.find_one('_id' => BSON::ObjectId(id))
        end # find_by_id

        def find(*args)
          db.find(*args)
        end # find

        def find_all
          find({ })
        end # find_all


      end # << self

    end # Requests

    DEFAULT_DATABASE_NAME = 'EpisodeEngine'

    configure :development do
      #enable :logging
      #register Sinatra::Reloader
    end

    def record_request(subject, system = nil, route = nil)
      request_as_hash = request_to_hash
      request_as_hash[:route] = route.to_s
      request_as_hash[:system] = system.to_s
      id = Requests.insert(request_as_hash, subject, system)
      id
    end # record_request


    ## ROUTES BEGIN ####################################################################################################
    before { log_request }

    ### API ROUTES BEGIN
    post '/api' do
      log_request_match(__method__)
      _params = params.dup
      _params = merge_params_from_body(_params)

      command = search_hash!(_params, :procedure, :method, :command)
      method_name = command.sub('-', '_').to_sym
      method_arguments = search_hash!(_params, :arguments)
      method_arguments = JSON.parse(method_arguments) rescue method_arguments if method_arguments.is_a?(String)
      logger.debug { "\nCommand: #{method_name}\nArguments: #{method_arguments}" }

      send_args = [ method_name ]
      send_args << method_arguments if method_arguments
      response = episode_api.send(*send_args)
      logger.debug { "Response: #{response}" }
      format_response(response)
    end
    ### API ROUTES END

    ### JOB ROUTES BEGIN

    get '/jobs/:job_id' do
      log_request_match(__method__)
    end

    get '/jobs' do

    end

    get '/jobs/cancel/:job_id' do

    end


    post '/jobs' do
      log_request_match(__method__)
      request_id = record_request(:job, :episode_engine, __method__)
      _params = params.dup
      _params = merge_params_from_body(_params)

      send_to_ubiquity = search_hash!(_params, :send_to_ubiquity, { :ignore_strings => %w(_ -), :case_sensitive => false })
      arguments = search_hash!(_params, :arguments)
      if send_to_ubiquity

      else

        api = episode_api(_params)

        if arguments
          _response = api.submit_build_submission(arguments)
        else
          _response = { 'error' => { 'message' => 'arguments is a required argument.'}}
        end
      end

      error = _response['error']
      error_occurred = error.respond_to?(:empty?) ? !error.empty? : !!error


      response = { :request => { :id => request_id.to_s }, :response => { :source => 'episode', :content => _response.inspect }, :success => !error_occurred }
      Requests.update(request_id, { :response => response[:response], :success => response[:success] })
      format_response(response)
    end

    put '/jobs/:id' do
      log_request_match(__method__)

    end
    ### JOB ROUTES END

    ### REQUEST ROUTES BEGIN
    get '/requests' do
      log_request_match(__method__)
      requests = Requests.find_all
      format_response({ :requests => requests })
    end

    get '/requests/:id' do
      log_request_match(__method__)
      id = params['id']
      _request = Requests.find_by_id(id)

      system_name = _request[:system]
      system_response = case system_name
                        when :ubiquity; process_ubiquity_job_status_request(_request)
                        else; { }
      end
      response = _request
      response[:latest_status] = system_response

      logger.debug { "Response Finding Request #{id}: #{response}" }
      format_response(response)
    end
    ### REQUEST ROUTES END


    ### UBIQUITY ROUTES BEGIN

    # Builds a workflow using the default workflow name.
    # Requires source_file_path
    post '/ubiquity/submit' do
      log_request_match(__method__)
      request_id = record_request(:job, :ubiquity, __method__)
      _params = merge_params_from_body

      submitter_ip = request.ip
      submitter_host = request.env['REMOTE_HOST']
      submitter_address = submitter_host || submitter_ip

      submitter_id = search_hash!(_params, :submitter_id, { :ignore_strings => %w(_ -), :case_sensitive => false })
      submitter_id ||= submitter_address

      _params[:submitter_ip] = submitter_ip
      _params[:submitter_host] = submitter_host
      _params[:submitter_address] = submitter_address
      _params[:submitter_id] = submitter_id

      Ubiquity.logger = logger

      _response = Ubiquity.submit(_params, settings.ubiquity_options)
      success = _response[:success]

      response = { :request => { :id => request_id.to_s }, :response => { :source => 'ubiquity', :content => _response }, :success => success }
      Requests.update(request_id, { :response => response[:response], :success => response[:success] })
      logger.debug { "Response: #{response}" }
      format_response(response)
    end

    # Passthrough for submitting ubiquity jobs
    # Requires that workflow-name and optionally workflow-parameters be defined
    post '/ubiquity' do
      log_request_match(__method__)
      request_id = record_request(:job, :ubiquity, __method__)
      _params = merge_params_from_body

      _response = Ubiquity::Submitter.submit(_params)
      format_response(_response)
    end
    ### UBIQUITY ROUTES END

    # Shows what gems are within scope. Used for diagnostics and troubleshooting.
    get '/gems' do
      cmd_line = 'gem list -b'
      stdout_str, stderr_str, status = Open3.capture3(cmd_line)
      #response = { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => status.success? }
      stdout_str.gsub("\n", '<br/>')
    end


    ### CATCH ALL ROUTES BEGIN
    get /.*/ do
      log_request_match(__method__)
      request_to_s.gsub("\n", '<br/>')
    end

    post /.*/ do
      log_request_match(__method__)
      #request_id = requests.insert(_request)
    end
    ### CATCH ALL ROUTES END


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

    # Will try to convert a body to parameters and merge them into the params hash
    # Params will override the body parameters
    #
    # @params [Hash] _params (params) The parameters parsed from the query and form fields
    def merge_params_from_body(_params = params)
      _params = _params.dup
      if request.media_type == 'application/json'
        request.body.rewind
        body_contents = request.body.read
        logger.debug { "Parsing: '#{body_contents}'" }
        if body_contents
          json_params = JSON.parse(body_contents)
          if json_params.is_a?(Hash)
            _params = json_params.merge(_params)
          else
            _params['body'] = json_params
          end
        end
      end
      _params
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
      [ :request_method, :url, :host, :path, :script_name, :query_string, :xhr?,
        :ip, :user_agent, :cookies,
        :media_type, :params,
        ].each { |method_name| out[method_name] = _request.send(method_name) }
      #out[:env] = request['env'].map { |entry| entry.to_s }
      out[:accept] = _request.accept.map { |entry| entry.to_s }
      out[:preferred_type] = request.preferred_type.to_s
      body = _request.body
      out[:body] = body ? body.dup.read : ''
      out
    end # request_to_hash

    # @param [Hash] params
    # @option params []
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
      logger.debug { "New Request. Via Route: #{route}\n#{request_to_s}" }
      #puts requests.insert(request_to_hash)
    end # log_request

    def log_request_match(route)
      logger.debug { "MATCHED: #{request.url} -> #{route}\nParsed Parameters: #{params}" }
    end # log_request_match

    def process_request(args = {})

    end # process_request

    def get_ubiquity_job_status(job_id)
      @sm ||= EpisodeEngine::Ubiquity::SubmissionManager.new
      @sm.submission_get_by_ubiquity_job_id(job_id).first
    end # get_ubiquity_job_status

    def process_ubiquity_job_status_request(_request)
      out = { }

      _response = _request[:response]
      source_file_paths = _response[:content]
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
    end

    def self.initialize_db(args = {})
      db = EpisodeEngine::Database::Mongo.new(args)
      #db_client = ::Mongo::MongoClient.new(args[:database_host_name], args[:database_port])
      #db = db_client.db(args[:database_name] || DEFAULT_DATABASE_NAME)
      #db.authenticate(args[:database_user_name, args[:database_password]]) if args[:database_user_name]
      db
    end # set_initialize_db

    def self.initialize_logger(args = {})
      logger = Logger.new(args[:log_to] || STDOUT)
      logger.level = args[:log_level] if args[:log_level]
      logger
    end # self.initialize_logger

    def self.initialize_api(args = {})
      api = EpisodeEngine::API::Adapters::XMLRPC.new(args)
      api
    end # self.initialize_api

    def self.initialize_ubiquity(args = {})
      ubiquity_submission_method = args[:ubiquity_submission_method]

      ubiquity_executable_path = args[:ubiquity_executable_path]
      ubiquity_submission_workflow_name = args[:ubiquity_submission_workflow_name] || Ubiquity::DEFAULT_WORKFLOW_NAME
      ubiquity_submission_missing_lookup_workflow_name = args[:ubiquity_submission_missing_lookup_workflow_name] || Ubiquity::DEFAULT_TRANSCODE_SETTINGS_NOT_FOUND_WORKFLOW_NAME

      mig_executable_file_path = args[:mig_executable_file_path] || Ubiquity::DEFAULT_MIG_EXECUTABLE_PATH

      workbook_username = args[:transcode_settings_google_workbook_username]
      workbook_password = args[:transcode_settings_google_workbook_password]
      google_workbook_id = args[:transcode_settings_google_workbook_id] || Ubiquity::TranscodeSettingsLookup::DEFAULT_TRANSCODE_SETTINGS_GOOGLE_WORKBOOK_ID
      workbook_file_path = args[:transcode_settings_workbook_file_path]

      ubiquity_options = {
        :google_workbook_id => google_workbook_id,
        :google_workbook_username => workbook_username,
        :google_workbook_password => workbook_password,
        :submission_workflow_name => ubiquity_submission_workflow_name,
        :submission_missing_lookup_workflow_name => ubiquity_submission_missing_lookup_workflow_name,
        :mig_executable_file_path => mig_executable_file_path
      }

      ubiquity_options
    end # self.initialize_ubiquity

    def self.init(args = {})
      set(:bind, args.delete(:binding))
      set(:port, args.delete(:local_port))
      set(:initial_options, args)

      logger = initialize_logger(args)
      set(:logger, logger)

      db = initialize_db(args)
      set(:db, db)

      api = initialize_api(args)
      set(:default_episode_api, api)

      ubiquity_options = initialize_ubiquity(args)
      set(:ubiquity_options, ubiquity_options)

    end # self.init


    def self.run!(*)
      super

      # Initialize Status Poller
    end

    #
    attr_accessor :logger

    #
    attr_accessor :db

    #
    attr_accessor :requests

    #
    attr_accessor :default_episode_api

    ## @param [Hash] args
    ## @option args [Logger] :logger
    ## @option args [String] :log_to
    ## @option args [Integer] :log_level
    def initialize(args = {})
      @logger = self.class.logger
      logger.debug { 'Initializing Episode Engine HTTP Application' }

      #params = self.class.initial_options.merge(args)
      #@db = params[:db]

      @db = self.class.db
      requests_db = db.dup
      requests_db.collection = 'requests'
      Requests.db = requests_db

      @default_episode_api = self.class.default_episode_api

      super
    end # initialize

  end # HTTP

end # EpisodeEngine

