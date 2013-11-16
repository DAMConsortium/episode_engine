module EpisodeEngine

  class StatusTracker

    attr_accessor :logger

    attr_accessor :requests

    attr_accessor :jobs

    def initialize(args = { })
      @logger = args[:logger]
      logger.debug { 'Initializing Status Tracker.' }

      @requests = args[:requests]
      @jobs = args[:jobs]


      logger.debug {
        rcount = requests.find_all.length
        jcount = jobs.find_all.length

        "Counts\n\tRequests: #{rcount}\n\tJobs: #{jcount}"
      }
    end # initialize


    def process_job(job)

    end # process_job

    def process_jobs(jobs)
      jobs.each { |job| process_job(job) }
    end # process_jobs

    # Gets the records of uncompleted jobs
    def get_uncompleted_jobs
      jobs = [ ]
      jobs
    end # get_uncompleted_jobs

    def process_request(request)

    end # process_request

    def process_requests(_requests)
      _requests.each { |request| process_request(request) }
    end # process_requests

    def get_uncompleted_requests
      _requests = [ ]
      _requests
    end # get_uncompleted_requests

    def run
      logger.debug { 'Running Status Tracker.' }
      process_requests(get_uncompleted_requests)
      process_jobs(get_uncompleted_jobs)
    end # run

  end # StatusTracker

end # EpisodeEngine