require 'mongo'
require 'mongoize'

module EpisodeEngine

  class Requests

    class Database

    DEFAULT_COLLECTION_NAME = 'requests'

    def initialize(args = { })
      args[:collection_name] ||= DEFAULT_COLLECTION_NAME
      super(args)
    end # initialize

    end # Database

  end # Requests

end # EpisodeEngine