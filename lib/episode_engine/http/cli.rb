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
        op.on('--log-to FILEPATH', 'The location to log to.', "\tdefault: STDOUT") { |v| options[:log_to] = v }

        op.on('--log-level LEVEL', LOGGING_LEVELS.keys,
              "Logging level. Available Options: #{LOGGING_LEVELS.keys.join(', ')}",
              "\tdefault: #{LOGGING_LEVELS.invert[options[:log_level]]}") { |v| options[:log_level] = LOGGING_LEVELS[v] }

        op.on('--[no-]options-file [FILEPATH]', 'An option file to use to set additional command line options.' ) do |v|
          options[:options_file_name] = v
        end
        op.on('--ubiquity-executable-path FILEPATH', 'The path to the Ubiquity executable.',
              'default: /usr/local/bin/uu') { |v| options[:uu_executable_path] = v }
        op.on_tail('-h', '--help', 'Show this message.') { puts op; exit }

        # Parse the command line so that we can see if we have an options file
        op.parse!(ARGV.dup)
        options_file_name = options[:options_file_name]

        # Make sure that options from the command line override those from the options file
        op.parse!(ARGV.dup) if op.load(options_file_name)

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