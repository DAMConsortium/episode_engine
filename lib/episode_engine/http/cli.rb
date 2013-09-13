require 'episode_engine/cli'
require 'episode_engine/http'
require 'episode_engine/requests'
module EpisodeEngine

  class HTTP

    class CLI < EpisodeEngine::CLI

      def parse_options
        options = {
            :log_to => STDOUT,
            :log_level => Logger::DEBUG,
        }

        op = OptionParser.new
        op.on('--binding BINDING', 'The address to bind the callback server to.',
              "\tdefault: #{options[:binding]}") do |v|
          options[:binding] = v
        end
        op.on('--port PORT', 'The port that the callback server should listen on.',
              "\tdefault: #{options[:local_port]}") do |v|
          options[:local_port] = v
        end

        op.on('--ubiquity-executable-path FILEPATH', 'The path to the Ubiquity executable.',
              'default: /usr/local/bin/uu') { |v| options[:uu_executable_path] = v }
        op.on('--ubiquity-submission-workflow-name NAME', ' ') { |v| options[:ubiquity_submission_workflow_name] = v }
        op.on('--ubiquity-submission-missing-lookup-workflow-name NAME', ' ') { |v| options[:ubiquity_submission_missing_lookup_workflow_name] = v }
        op.on('--mig-path FILEPATH', '') { |v| options[:mig_executable_file_path] = v }
        op.on('--workbook-username USERNAME', '') { |v| options[:transcode_settings_google_workbook_username] = v }
        op.on('--workbook-password PASSWORD', '') { |v| options[:transcode_settings_google_workbook_password] = v }
        op.on('--workbook-id ID', '') { |v| options[:transcode_settings_google_workbook_id] = v }
        op.on('--workbook-file-path FILEPATH', ' ') { |v| options[:transcode_settings_workbook_file_path] = v }


        op.on('--log-to FILEPATH', 'The location to log to.', "\tdefault: STDOUT") { |v| options[:log_to] = v }

        op.on('--log-level LEVEL', LOGGING_LEVELS.keys,
              "Logging level. Available Options: #{LOGGING_LEVELS.keys.join(', ')}",
              "\tdefault: #{LOGGING_LEVELS.invert[options[:log_level]]}") { |v| options[:log_level] = LOGGING_LEVELS[v] }

        op.on('--[no-]options-file [FILEPATH]', 'An option file to use to set additional command line options.' ) do |v|
          options[:options_file_name] = v
        end

        op.on_tail('-h', '--help', 'Show this message.') { puts op; exit }

        # Parse the command line so that we can see if we have an options file
        op.parse!(ARGV.dup)
        options_file_name = options[:options_file_name]

        unless options_file_name === false
          # Make sure that options from the command line override those from the options file
          op.parse!(ARGV.dup) if op.load(options_file_name)
        end

        options[:logger] = logger
        options
      end # parse_options

      def initialize(args = {})
        args = parse_options.merge(args)
        app = EpisodeEngine::HTTP
        app.init(args)
        app.run!
      end # initialize

    end # CLI

  end # HTTP

end # EpisodeEngine

#ubiquity_options = {
#    :workbook_username => workbook_username,
#    :workbook_password => workbook_password,
#    :google_workbook_id => google_workbook_id,
#    :ubiquity_submission_workflow_name => ubiquity_submission_workflow_name,
#    :ubiquity_submission_missing_lookup_workflow_name => ubiquity_submission_missing_lookup_workflow_name,
#    :mig_executable_file_path => mig_executable_file_path
#}