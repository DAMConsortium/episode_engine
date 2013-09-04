# file://localhost/Applications/Episode.app/Contents/MacOS/engine/API/XMLRPC/Doc/XMLRPC.html
require 'xmlrpc/client'

require 'episode_engine/api/adapters/adapter'
module EpisodeEngine

  module API

    module Adapters

      class XMLRPC < Adapter

        attr_accessor :episode

        DEFAULT_HOST_ADDRESS = '127.0.0.1'
        DEFAULT_HOST_PORT = 40431

        # @param [Hash] args
        def initialize(args = {})

          host_address = args[:host_address] || DEFAULT_HOST_ADDRESS
          host_port = args[:host_port] || DEFAULT_HOST_PORT

          # Connect to Episode XMLRPC server
          @episode = ::XMLRPC::Client.new2("http://#{host_address}:#{host_port}")
        end # initialize

        def call(command, args = { }, options = {})
          episode.call(command, args)
        end # call

        def get_version
          call('getVersion')
        end # get_version

        def status_bonjour
          call('statusBonjour')
        end # status_bonjour

        def node_info_cluster(args = {})
          call('nodeInfoCluster', args)
        end # node_info_cluster

        def task_create_transfer(args = {})
          call('taskCreateTransfer', args)
        end # task_create_transfer

        def task_create_youtube(args = {})
          call('taskCreateYouTube', args)
        end # task_create_youtube

        def task_create_execute(args = {})
          call('taskCreateExecute', args)
        end # task_create_execute

        def task_create_mail(args = {})
          call('taskCreateMail', args)
        end # task_create_mail

        def task_create_mgr(args = {})
          call('taskCreateMBR', args)
        end # task_create_mgr

        def sourceCreateFileList(args = {})
          call('sourceCreateFileList', args)
        end # sourceCreateFileList

        def source_create_monitor(args = {})
          call('sourceCreateMonitor', args)
        end # source_create_monitor

        def source_create_edl(args = {})
          call('sourceCreateEDL', args)
        end # source_create_edl

        def source_create_seq(args = {})
          call('sourceCreateSEQ', args)
        end # source_create_seq

        def submit_build_submission(args = {})
          call('submitBuildSubmission', args)
        end # submit_build_submission

        def submit_submission(args = {})
          call('submitSubmission', args)
        end # submit_submission

        def status_tasks2(args = { })
          call('statusTasks2', args)
        end # status_tasks2
        alias :status_tasks :status_tasks2

        def status_workflows2(args = {})
          call('statusWorkflows2', args)
        end # status_workflows2
        alias :status_workflows :status_workflows2

        def job_cancel(args = {})
          call('jobCancel', args)
        end # job_cancel

        def job_pause(args = {})
          call('jobPause', args)
        end # job_pause

        def job_resume(args = {})
          call('jobResume', args)
        end # job_resume

        def job_requeue(args = {})
          call('jobRequeue', args)
        end # job_requeue

        def job_set_priority(args = {})
          call('jobSetPriority', args)
        end # job_set_priority

        def status_monitors(args = {})
          call('statusMonitors', args)
        end # status_monitors

        def monitor_start(args = {})
          call('monitorStart', args)
        end # monitor_start

        def monitor_set_priority(args = {})
          call('monitorSetPriority', args)
        end # monitor_set_priority

        def monitor_stop(args = {})
          call('monitorStop', args)
        end # monitor_stop

        def monitor_remove(args = {})
          call('monitorRemove', args)
        end # monitor_remove

        def submission_recall(args = {})
          call('submissionRecall', args)
        end # submission_recall

        def history_remove_workflow(args = {})
          call('historyRemoveWorkflow', args)
        end # history_remove_workflow

        def analyze_file(args = {})
          call('analyzeFile', args)
        end # analyze_file

      end # XMLRPC

    end # Adapters

  end # API

end # EpisodeEngine
