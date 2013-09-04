require 'poller'

require 'episode_engine/database'

module EpisodeEngine

  class Poller < ::Poller

    attr_accessor :db

    def initialize(args = { })
      @db = EpisodeEngine::Database::Mongo.new(args)

    end # initialize

    def process_requests
      requests = @db['requests'].find
      requests.each { |request| process_request(request) }
    end # process_requests

    def process_request(request)
      # TODO: GET JOBS FROM request
      jobs = [ ]
      process_jobs(jobs)
    end # process_request

    def process_jobs(jobs)
      jobs.each { |job| process_job(job) }
    end # process_jobs

    def process_job(job)

      # TODO: FILL OUT process_job method
      # Get Job ID
      # Poll Job Status
      # Update Records Job Status

    end # process_job

  end # Poller

end # EpisodeEngine