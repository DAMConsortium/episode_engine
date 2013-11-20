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
        logger.debug { "UBIQUITY JOB#{job ? ":\n#{PP.pp(job, '')}" : " NOT FOUND. (#{job_id}"})" }
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
        return unless job_id and !job_id.empty?

        if _job.has_key?('status')
          job_status = _job['status']
        else
          job_from_ubiquity = jobs.find_by_id(job_id)
          job_status = job_from_ubiquity['status']
        end
        job_status == 'completed'
      end

      def parse_job_status(job)
        return false unless job.is_a?(Hash)

        # Failure is not an option
        # return true
        logger.debug { "Processing job to determine if it was successful. #{PP.pp(job, '')}" }
        history = job['history']
        #logger.debug { "Job History: #{PP.pp(history, '')}" }
        latest_update_key = history.keys.sort.last
        latest_update = history[latest_update_key]
        #@logger.debug { "Latest Historical Update: (#{latest_update_key}) #{PP.pp(latest_update, '')}" }
        _job = latest_update['job']
        #@logger.debug { "JOB: #{PP.pp(_job, '')}"}
        run_time = _job[:run_time]
        #@logger.debug { "JOB RUN TIME: #{PP.pp(run_time, '')}" }
        workflow = run_time[:workflow]
        #@logger.debug { "JOB WORKFLOW: #{PP.pp(workflow, '')}" }
        tasks = workflow[:tasks]
        #@logger.debug { "JOB WORKFLOW TASKS: #{PP.pp(tasks, '')}" }
        processed_tasks = tasks[:processed]
        #@logger.debug { "JOB PROCESSED TASKS: #{PP.pp(processed_tasks, '')}"}

        # TODO: VERIFY THAT IT IS THE LAST TASK
        latest_task = processed_tasks.last
        result = latest_task[:result]
        @logger.debug { "Result: #{result}" }
        success = result[:type] != 'error'
        @logger.debug { "SUCCESS? #{success}" }

        unless success
          result_values = result['values'] || { }
          error = result_values['error']
          error_message = result_values['error_message']
          if error_message and !error
            error = { :message => error_message }
          end
        end
        { :success => success, :error => error }
      end

      def set_job_status(job, status, success = nil, error = nil)
        job[:status] = status
        job[:success] = success
        job[:error] = error
        job
      end

      def process_request_jobs_by_state(request_jobs)
        uncompleted_request_jobs = [ ]
        unknown_request_jobs = [ ]

        successful_jobs = [ ]
        failed_jobs = [ ]

        request_jobs.dup.each do |job_id, request_job|
          next unless job_id and !job_id.empty?

          ubiquity_job = get_job_from_ubiquity(job_id)
          unless ubiquity_job
            unknown_request_jobs << request_job
            request_jobs[job_id] = set_job_status(request_job, 'unknown')
            next
          end

          if is_job_completed?(ubiquity_job)
            _job_status = parse_job_status(ubiquity_job)
            job_success = _job_status[:success]
            job_error = _job_status[:error]
            if job_success
              successful_jobs << request_job
              job_status = 'completed'
            else
              failed_jobs << request_job
              job_status = 'completed'
            end
          else
            uncompleted_request_jobs << request_job
            job_status = 'running'
            job_success = nil
            job_error = nil
          end
          request_jobs[job_id] = set_job_status(request_job, job_status, job_success, job_error)
        end

        completed_request_jobs = { :successful => successful_jobs, :failed => failed_jobs }
        { :completed => completed_request_jobs, :uncompleted => uncompleted_request_jobs, :unknown => unknown_request_jobs, :jobs_with_status => request_jobs }
      end

      def process_uncompleted_request(request)
        logger.debug { "Processing Status for Request: #{request}" }
        request_jobs = get_jobs_from_request(request)

        request_id = request['_id']
        request_jobs_by_state = process_request_jobs_by_state(request_jobs)

        uncompleted_jobs = request_jobs_by_state[:uncompleted]
        unknown_jobs = request_jobs_by_state[:unknown]
        completed_jobs = request_jobs_by_state[:completed]
        #successful_jobs = completed_jobs[:successful]
        failed_jobs = completed_jobs[:failed]

        completed = false
        success = nil
        if !unknown_jobs.empty?
          request_status = 'unknown'
        elsif !uncompleted_jobs.empty?
          request_status = 'running'
        else
          request_status = 'completed'
          completed = true
          success = failed_jobs.empty?
        end
        jobs_with_status = request_jobs_by_state[:jobs_with_status]

        logger.debug { "Updating Request Status To: #{request_status} "}

        requests.update_status(request_id, request_status, 'completed' => completed, 'success' => success, 'ubiquity' => { :jobs => jobs_with_status })
      end # process_request

      def process_uncompleted_requests(_requests = nil)
        _requests ||= get_uncompleted_requests
        _requests.each { |request| process_uncompleted_request(request) }
      end # process_requests

      def get_uncompleted_requests
        #_requests = requests.find({ 'system' => 'ubiquity', 'status' => { '$ne' => 'completed' } })
        #_requests = requests.find({ 'system' => 'ubiquity', 'completed' => { '$ne' => true } })
        _requests = requests.find({ 'system' => 'ubiquity' })
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

