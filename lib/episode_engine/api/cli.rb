require 'json'
require 'pp'

require 'episode_engine/api/adapters/xmlrpc'
require 'episode_engine/cli'
module EpisodeEngine

  module API

    class CLI < EpisodeEngine::CLI

      attr_accessor :episode

      def parse_options
        ARGV << '-h' if ARGV.empty?
        _options = {
          :log_to => STDERR,
          :log_level => Logger::WARN,
        }
        op = OptionParser.new
        op.on('--host-address ADDRESS', 'The address of the Episode Engine XMLRPC Server.') { |v| _options[:host_address] = v }
        op.on('--method-name METHODNAME', 'The name of the method/procedure to call.') { |v| _options[:method_name] = v }
        op.on('--method-arguments JSON', 'A JSON String with the arguments to be passed to the method being called.') { |v| _options[:method_arguments] = JSON.parse(v) }
        op.on('--pretty-print', 'Formats the output in a "pretty" format.') { |v| _options[:pretty_print] = v }
        op.on('-h', '--help', 'Display Help.') { puts op; exit; }
        op.load
        op.parse!(ARGV.dup)

        options_file_path = _options[:options_file_path]
        if options_file_path
          op.load(options_file_path)
          op.parse!(ARGV.dup)
        end

        unless _options[:method_name]
          puts op
          exit
        end

        _options
      end # parse_options

      def initialize(params = {})
        options = parse_options
        method_name = options[:method_name]
        if method_name
          api = EpisodeEngine::API::Adapters::XMLRPC.new(options)

          send_args = [ method_name ]

          method_arguments = options[:method_arguments]
          send_args << method_arguments if method_arguments
          response = api.send(*send_args)
          if options[:pretty_print]
            pp response
          else
            puts response
          end
          exit
        end
      end # initialize

      def send(method_name, method_arguments, params = {})
        method_name = method_name.to_sym
        logger.debug { "Executing Method: #{method_name}" }

        send_arguments = [ method_name ]

        if method_arguments
          method_arguments = JSON.parse(method_arguments) if method_arguments.is_a?(String) and method_arguments.start_with?('{', '[')
          send_arguments << method_arguments
        end

        response = episode.__send__(*send_arguments)
        response.to_json
      end # send

    end # CLI

  end # API

end # EpisodeEngine