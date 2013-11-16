module EpisodeEngine

  class HTTP

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

    ### EPISODE JOB ROUTES BEGIN

    get '/jobs/:job_id' do; log_request_match(__method__) end

    get '/jobs' do; end

    get '/jobs/cancel/:job_id' do; end

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
      Database::Helpers::Requests.update(request_id, { :response => response[:response], :success => response[:success] })
      format_response(response)
    end
    ### EPISODE JOB ROUTES END


  end # HTTP

end # EpisodeEngine