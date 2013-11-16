module EpisodeEngine

  class HTTP

    before { log_request }

    ### REQUEST ROUTES BEGIN
    load('episode_engine/http/routes/requests.rb')
    ### REQUEST ROUTES END

    ### EPISODE ROUTES BEGIN
    load('episode_engine/http/routes/episode.rb')
    ### EPISODE ROUTES END

    ### UBIQUITY ROUTES BEGIN
    load('episode_engine/http/routes/ubiquity.rb')
    ### UBIQUITY ROUTES END

    # Shows what gems are within scope. Used for diagnostics and troubleshooting.
    get '/gems' do
      cmd_line = 'gem list -b'
      stdout_str, stderr_str, status = Open3.capture3(cmd_line)
      #response = { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => status.success? }
      stdout_str.gsub("\n", '<br/>')
    end

    get '/favicon.ico' do

    end

    ### CATCH ALL ROUTES BEGIN
    get /.*/ do
      log_request_match(__method__)
      request_to_s.gsub("\n", '<br/>')
    end

    #post /.*/ do
    #  log_request_match(__method__)
    #  #request_id = requests.insert(_request)
    #end
    ### CATCH ALL ROUTES END

  end # HTTP

end # EpisodeEngine