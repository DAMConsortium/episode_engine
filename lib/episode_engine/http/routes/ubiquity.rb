module EpisodeEngine

  class HTTP

    ### UBIQUITY ROUTES BEGIN

    # Passthrough for submitting ubiquity jobs
    # Requires that workflow-name and optionally workflow-parameters be defined
    post '/ubiquity' do
      log_request_match(__method__)
      request_id = record_request(:job, :ubiquity, __method__)
      _params = merge_params_from_body
      begin
        _response = Ubiquity::Submitter.submit(_params)
      rescue => e
        _response = {:exception => {:message => e.message, :backtrace => e.backtrace}}
      end
      format_response(_response)
    end

    get '/ubiquity/job/:ubiquity_job_id' do
      log_request_match(__method__)
      ubiquity_job_id = params[:ubiquity_job_id]
      results = settings.ubiquity_jobs.find(ubiquity_job_id)
      format_response(results)
    end

    # Query requests handled by ubiquity
    get '/ubiquity/requests/*' do
      log_request_match(__method__)
      criteria = params[:splat].first


      #criteria = params[:criteria]
      if criteria.is_a?(String)
        criteria, format = criteria.split('.')
        status, date_from, date_to = criteria.split('/')
        logger.debug { "Format: '#{format}' Status: '#{status}' Date From: '#{date_from}' To: '#{date_to}'" }
      else
        date_from = date_to = nil
      end
      status ||= :all

      selector = { }
      if date_from
        _date_from, _date_to = DateTimeHelper.process_range(date_from, date_to)
        selector['created_at'] = { '$gte' => _date_from.to_i, '$lte' => _date_to.to_i }
      end

      show_detail_param = search_hash(params, :show_detail, :detail)
      show_detail = (show_detail_param and (%w(true 1).include?(show_detail_param.downcase)))

      output_html_param = search_hash(params, :html, :output_html)
      output_html = (output_html_param and (%w(true 1).include?(output_html_param.downcase)))
      output_html ||= %w(html htm).include?(format)

      pagination_options = Database::Helpers::Requests.process_query_pagination_parameters(params)
      options = pagination_options.dup
      options[:sort] = 'created_at'

      unknown_job_status = false
      job_status = status.downcase.to_sym
      case job_status
        when :running, :uncompleted
          # Not Completed
          selector['completed'] = { '$ne' => true }
        when :unknown
          selector['status'] = 'unknown'
        when :completed
          # Completed
          selector['completed'] = true
        when :failed
          # Completed And Failed
          selector['completed'] = true
          selector['success'] = false
        when :success, :successful
          # Completed and Successful
          selector['completed'] = true
          selector['success'] = true
        when :cancelled, :canceled
          # Future Implementation
        when :all, :any
          # All regardless of status
        else
          _response = { :error => { :message => "Unknown Job Status. '#{job_status}'" } }
          unknown_job_status = true
      end

      unless unknown_job_status
        logger.debug { "Searching for #{job_status} jobs. From: #{date_from} (#{_date_from}) To: #{date_to} (#{_date_to})\n\tSelector: #{selector}\n\tOptions: #{options}" }
        begin
          _requests = settings.requests.find(selector, options)
          _requests = _requests.map { |request| _request = { :id => request.delete('_id').to_s }; _request.merge(request) }
          if _requests
            total_requests = _requests.length
            #_requests.slice(pagination_options[:skip], pagination_options[:limit])
          else
            total_requests = 0
          end
        rescue => e
          _response = { :exception => { :message => e.message, :backtrace => e.backtrace } }
        end
      end

      _requests ||= { }
      _response ||= { }

      #query_vitals = {
      #  status: status,
      #  from_date: date_from,
      #  to_date: date_to,
      #  translated_from_date: _date_from,
      #  translated_to_date: _date_to,
      #  selector: selector,
      #  options: options,
      #  requests: _requests,
      #  response: _response,
      #}


      if output_html
        content_type :html
        status_html = '<html><head></head><body>'
        status_html << "Params: #{PP.pp(params, '')}"
        status_html << "Status: #{status}<br/>"
        status_html << "From Date: #{date_from}<br/>"
        status_html << "To Date: #{date_to}<br/>"
        status_html << "Translated From Date: #{_date_from}<br/>"
        status_html << "Translated To Date: #{_date_to}<br/>"
        status_html << "Selector: #{selector}<br/>"
        status_html << "Options: #{options}<br/>"
        #status_html << "Pagination: #{pagination_options}<br/><br/>"
        status_html << "#{_response ? "<br/>Response: <pre>#{PP.pp(_response, '')}</pre>" : ''}<br/>"
        status_html << "Requests: (#{_requests ? _requests.length : 0}) #{show_detail ? " Detail: <pre>#{PP.pp(_requests, '')}</pre>" : " Summary: <pre>#{PP.pp(summarize_requests(_requests), '')}</pre>"}"
        status_html << '</body></html>'
        return status_html
      end

      _response[:total] = total_requests
      _response.merge!(pagination_options)
      _response[:requests] = show_detail ? _requests : summarize_requests(_requests)
      format_response(_response)
    end

    # Builds a workflow using the default workflow name.
    # Requires source_file_path
    post '/ubiquity/submit' do
      log_request_match(__method__)
      request_id = record_request(:job, :ubiquity, __method__)
      _params = merge_params_from_body

      _submitter = submitter
      _params.merge!(_submitter)

      _response = Ubiquity.submit(_params, settings.ubiquity_options)
      _jobs = Ubiquity.get_jobs_from_response(_response)
      success = _response[:success]

      response = { :request => { :id => request_id.to_s }, :response => { :source => 'ubiquity', :content => _response }, :ubiquity => { :jobs => _jobs }, :success => success }

      Database::Helpers::Requests.update(request_id, { 'response' => response[:response], 'ubiquity' => { :jobs => _jobs } })
      #Database::Models::Requests.update(request_id, { :response => response[:response], :success => response[:success] })
      logger.debug { "Response: #{response}" }
      format_response(response)
    end

    post '/ubiquity/mig' do
      log_request_match(__method__)
      _params = merge_params_from_body
      _response = { }
      file_paths = _params[:file_paths]
      logger.debug { "File Paths: #{file_paths}" }
      [*file_paths].each do |file_path|
        logger.debug { "Processing File Path: #{file_path}" }
        begin
          _response[file_path] = Ubiquity.mig(file_path, settings.ubiquity_options)
        rescue => e
          _response[file_path] = {:exception => {:message => e.message, :backtrace => e.backtrace}}
        end
      end
      format_response(_response)
    end

    post '/ubiquity/transcode_settings' do
      log_request_match(__method__)
      _params = merge_params_from_body
      _response = { }
      file_paths = _params[:file_paths]
      logger.debug { "File Paths: #{file_paths}" }
      [*file_paths].each do |file_path|
        logger.debug { "Processing File Path: #{file_path}" }
        begin
          _response[file_path] = Ubiquity.mig_and_lookup_transcode_settings(file_path, settings.ubiquity_options)
        rescue => e
         _response[file_path] = {:exception => {:message => e.message, :backtrace => e.backtrace}}
        end
      end
      format_response(_response)
    end

    # Status Tracker Trigger
    get '/ubiquity/status_tracker' do
      status_tracker.run
      content_type :html
      'OK'
    end
    ### UBIQUITY ROUTES END

    def summarize_requests(_requests)
      return unless _requests
      summaries = [ ]
      _requests.each do |_r|
        request_summary = { }
        request_id = _r[:id] || _r['_id'].to_s
        action = _r['action']
        completed = _r['completed']
        status = _r['status']
        ubiquity_jobs = _r['ubiquity']

        request_summary[:id] = request_id
        request_summary[:action] = action
        request_summary[:completed] = completed
        request_summary[:status] = status
        #summaries << request_summary

        response = _r['response'] || { }
        content = response[:content] || { }
        sfp_summaries = { }
        content.each do |source_file_path, sfp_response|
          sfp_summary = { }
          tasks = sfp_response[:tasks] || { }
          task_summaries = { }
          tasks.each do |epitask_file_name, task|
            task_summary = { }
            submission = task[:submission]

            workflow = submission[:workflow] || { }
            workflow_name = workflow[:name]

            submission_response = submission[:response] || { }
            ubiquity_http_uri = submission_response[:uri]
            #ubiquity_http_response = submission_response[:body_as_hash] || { }
            #ubiquity_cli_command = ubiquity_http_response['cmd_line']
            #ubiquity_cli_response = ubiquity_http_response['response']
            submission_success = submission_response[:success]
            submission_job_id = submission_response[:job_id]

            task_summary[:uri] = ubiquity_http_uri
            task_summary[:workflow_name] = workflow_name
            task_summary[:success] = submission_success
            task_summary[:job_id] = submission_job_id
            #task_summary[:command_line] = ubiquity_cli_command
            #task_summary[:command_line_response] = ubiquity_cli_response
            #task_summary[:response] = submission_response

            task_summaries[epitask_file_name] = { :ubiquity_submission => task_summary }
          end # tasks
          sfp_summary[:tasks] = task_summaries
          sfp_summaries[source_file_path] = sfp_summary
        end # content

        ubiquity_jobs_summary = { }
        ubiquity_jobs.each do |ubiquity_job|
          _job_summary = { }
          _job_summary = ubiquity_job
          _job_summary.delete(:workflow)
        end

        request_summary[:source_files] = sfp_summaries
        request_summary[:ubiquity] = ubiquity_jobs_summary
        summaries << request_summary
      end
      summaries
    end # build_summaries_from_requests

  end # HTTP

end # EpisodeEngine
