require 'mongo'
module EpisodeEngine

  class Database

    DEFAULT_DATABASE_NAME = 'EpisodeEngine'

    class Mongo

      attr_accessor :client, :db, :col

      # @param [Hash] args
      # @option args [String] :database_host_address
      # @option args [String] :database_port
      # @option args [String] :database_name
      # @option args [String] :collection_name
      # @option args [String] :database_username
      # @option args [String] :database_password
      def initialize(args = { })
        @client = ::Mongo::MongoClient.new(args[:database_host_address], args[:database_port])

        @db = client.db(args[:database_name] || DEFAULT_DATABASE_NAME)
        db.authenticate(args[:database_username, args[:database_password]]) if args[:database_username]

        @col = @db.collection(args[:collection_name]) if args[:collection_name]
      end

      def collection=(collection_name)
        @col = db.collection(collection_name)
      end # collection

      def find_all
        find({ })
      end # find_all

      def find(*args); Mongoize.from_mongo(col.find(Mongoize.to_mongo(*args)).to_a) end # find

      def find_one(*args); Mongoize.from_mongo(col.find_one(Mongoize.to_mongo(*args))) end # find_one

      def insert(*args); col.insert(Mongoize.to_mongo(*args)) end # insert

      def remove(*args); col.remove(Mongoize.to_mongo(*args)) end # remove

      def update(id, document, opts = { })
        document = document.dup
        _document = { }
        %w($set $unset $push $rename $inc $setOnInsert, $bit, $isolated).each { |op|
          _document[op] = Mongoize.to_mongo(document.delete(op), :invalid_chr_patter => /^\./) if document[op]
        }
        _document = _document.merge(Mongoize.to_mongo(document, :invalid_chr_patter => /^\./))
        col.update(id, _document, opts)
      end # update

      def save(*args); col.save(Mongoize.to_mongo(*args)) end # save

    end # Mongo


  end # Database

end # EpisodeEngine
