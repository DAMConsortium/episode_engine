module EpisodeEngine

  class HTTP

    ### REQUEST ROUTES BEGIN
    get '/requests' do
      log_request_match(__method__)
      requests = Database::Helpers::Requests.find_all
      format_response({ :requests => requests })
    end

    get '/requests/:id' do
      log_request_match(__method__)
      id = params['id']
      _request = Database::Helpers::Requests.find_by_id(id)

      system_name = search_hash(_request, :system)
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

  end # HTTP

end # EpisodeEngine