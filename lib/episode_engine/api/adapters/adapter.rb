module EpisodeEngine

  module API

    class Adapter

      attr_accessor :logger

      def initialize(params = {})
        @logger = params[:logger] ||= Logger.new(params[:log_to] ||= STDOUT)
        logger.level = (log_level = params[:log_level]) ? log_level : Logger::WARN
        params[:logger] = logger
      end # initialize

    end # Adapter

  end # API

end # EpisodeEngine