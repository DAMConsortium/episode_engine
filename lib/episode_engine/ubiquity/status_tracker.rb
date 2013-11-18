require 'episode_engine/database'
module EpisodeEngine

  module Ubiquity

    class StatusTracker

      attr_accessor :logger

      attr_accessor :requests

      attr_accessor :jobs

      def initialize(args = { })
        @logger = args[:logger]
        logger.debug { 'Initializing Status Tracker.' }

        @requests = args[:requests]
        @jobs = args[:jobs]

        #logger.debug {
        #  rcount = requests.find_all.length
        #  jcount = jobs.find_all.length
        #
        #  "Counts\n\tRequests: #{rcount}\n\tJobs: #{jcount}"
        #}
      end # initialize

      def get_job_from_ubiquity(job_id)
        return job_id.map { |_job_id| get_job_from_ubiquity(_job_id) } if job_id.is_a?(Array)
        job = jobs.find_by_id(job_id)
        logger.debug { "JOB#{job ? ":\n#{PP.pp(job, '')}" : " NOT FOUND. (#{job_id}"})" }
        job
      end # get_job_from_ubiquity

      def process_job(job_from_episode)
        job_id = job_from_episode[:id]
        return unless job_id
        logger.debug { "Processing Job. #{job_id}" }

        job = get_job_from_ubiquity(job_id)
        return unless job

        job_status = job['status']
        logger.debug { "JOB KEYS: #{job.keys} STATUS: #{job_status}" }

        job_history = job['history']
        job_history_keys = job_history.keys
        #logger.debug { "JOB (#{job.keys}) HISTORY KEYS: #{job_history_keys}" }

        job_history_last_key = job_history_keys.sort.last
        job_history_last = job_history[job_history_last_key]

        job_history_last_status = job_history_last['status']
        logger.debug { "JOB HISTORY LAST: #{job_history_last.keys} STATUS: #{job_history_last_status} " }

      end # process_job

      def process_jobs(_jobs)
        _jobs.each { |job| process_job(job) }
      end # process_jobs


      def get_jobs_from_request(request)
        ubiquity = request['ubiquity']
        return [ ] unless ubiquity
        _jobs = ubiquity[:jobs] || { }
        _jobs
      end

      def is_job_completed?(_job)
        job_id = _job[:id] || _job['_id']
        return unless job_id

        if _job.has_key?('status')
          job_status = _job['status']
        else
          job_from_ubiquity = jobs.find_by_id(job_id)
          job_status = job_from_ubiquity['status']
        end
        job_status == 'completed'
      end

      def job_successful?(_job)
        return true
      end

      def process_request_jobs_by_state(request_jobs)
        uncompleted_request_jobs = [ ]
        unknown_request_jobs = [ ]

        successful_jobs = [ ]
        failed_jobs = [ ]

        request_jobs.each do |job_id, request_job|
          ubiquity_job = get_job_from_ubiquity(job_id)
          unless ubiquity_job
            unknown_request_jobs << request_job
            next
          end

          if is_job_completed?(ubiquity_job)
            if job_successful?(ubiquity_job)
              successful_jobs << request_job
            else
              failed_jobs << request_job
            end
          else
            uncompleted_request_jobs << request_job
          end
        end

        completed_request_jobs = { :successful => successful_jobs, :failed => failed_jobs }
        { :completed => completed_request_jobs, :uncompleted => uncompleted_request_jobs, :unknown => unknown_request_jobs }
      end

      def process_uncompleted_request(request)
        logger.debug { "Processing Status for Request: #{request}" }
        request_jobs = get_jobs_from_request(request)

        request_id = request['_id']
        request_jobs_by_state = process_request_jobs_by_state(request_jobs)

        uncompleted_jobs = request_jobs_by_state[:uncompleted]
        unknown_jobs = request_jobs_by_state[:unknown]

        completed = false
        if !unknown_jobs.empty?
          request_status = 'unknown'
        elsif !uncompleted_jobs.empty?
          request_status = 'running'
        else
          request_status = 'completed'
          completed = true
        end

        logger.debug { "Updating Request Status To: #{request_status} "}

        requests.update_status(request_id, request_status, 'completed' => completed)
      end # process_request

      def process_uncompleted_requests(_requests = nil)
        _requests ||= get_uncompleted_requests
        _requests.each { |request| process_uncompleted_request(request) }
      end # process_requests

      def get_uncompleted_requests
        #_requests = requests.find({ 'system' => 'ubiquity', 'status' => { '$ne' => 'completed' } })
        _requests = requests.find({ 'system' => 'ubiquity', 'completed' => { '$ne' => true } })
        logger.debug { "Found #{_requests.length} uncompleted request." }
        _requests
      end # get_uncompleted_requests

      def run
        logger.debug { 'Running Status Tracker.' }
        #logger.debug { "DATABASE:\n\tJOBS: #{jobs.db.db.name} | #{jobs.db.col.name}" }
        process_uncompleted_requests
        #process_jobs(get_uncompleted_jobs)
      end # run

    end # StatusTracker

  end # Ubiquity

end # EpisodeEngine

