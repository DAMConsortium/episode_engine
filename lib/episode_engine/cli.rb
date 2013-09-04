require 'logger'
require 'optparse'

module EpisodeEngine

  class CLI

    LOGGING_LEVELS = {
        :debug => Logger::DEBUG,
        :info => Logger::INFO,
        :warn => Logger::WARN,
        :error => Logger::ERROR,
        :fatal => Logger::FATAL
    }

    attr_accessor :logger

  end # CLI

end # EpisodeEngine