require 'mongo'
require 'mongoize'
module EpisodeEngine

  module Ubiquity

    class Database

      DEFAULT_DATABASE_NAME = 'ubiquity'

      class MongoDB

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

          @col = db.collection(args[:collection_name]) if args[:collection_name]
        end

        def collection=(collection_name)
          @col = db.collection(collection_name)
        end # collection

        def find(selector = { }, options = { })
          _selector = selector.is_a?(Hash) ? Mongoize.to_mongo(selector, recursive: false) : { '_id' => selector }
          cursor = col.find(_selector, options)
          results = cursor.to_a.map { |record| Mongoize.from_mongo(record) }
          results
        end # find

        def find_one(selector = { }, options = { })
          selector = selector.is_a?(Hash) ? Mongoize.to_mongo(selector, recursive: false) : { '_id' => selector }
          Mongoize.from_mongo(col.find_one(selector, options))
        end # find_one
        alias :get :find_one


        def find_all(options = { })
          find({ }, options)
        end # find_all
        alias :get_all :find_all

        #def find(selector, options = { });
        ##puts "DATABASE: #{@db.name}\nCOLLECTION: #{@col.name}\nSELECTOR: #{selector}\nOPTIONS: #{options}"
        #result = col.find(selector, options).to_a
        ##puts "RESULT: (#{result.count}) #{result}"
        #result
        #end # find
        #
        #def find_one(*args); col.find_one(*args) end # find_one

        def insert(*args); col.insert(*args) end # insert

        def remove(*args); col.remove(*args) end # remove

        def update(id, document, opts = { })
          #puts "#{self.class.name}.#{__method__}(#{id} #{document} #{opts}) DATABASE NAME: #{db.name} COLLECTION NAME: #{col.name}"
          col.update(id, document, opts)
        end # update

        def save(*args); col.save(*args) end # save

      end # MongoDB

      def self.new(args = { })
        args[:database_name] ||= self.const_get(:DEFAULT_DATABASE_NAME)
        #puts "DATABASE NAME: #{args[:database_name]}"
        args[:collection_name] ||= self.const_get(:DEFAULT_COLLECTION_NAME) if self.const_defined?(:DEFAULT_COLLECTION_NAME)
        MongoDB.new(args)
      end

      module Helpers

        class Common

          class << self

            attr_accessor :db

            def update(id, data, options = { })
              data['modified_at'] = Time.now.to_i
              query = options[:query] || {'_id' => id }

              unless data.has_key?('_id')
                data = { '$set' => data }
              end

              db.update(query, data)
            end # update

            def find_by_id(id)
              #db.find_one('_id' => BSON::ObjectId(id))
              db.find_one('_id' => id)
            end # find_by_id

            def find(*args)
              db.find(*args)
            end # find

            def find_one(*args); db.find_one(*args) end

            def find_all
              self.find({ })
            end # find_all

          end # self


        end # Common

        class Jobs < Common
          class << self

            def db=(_db)
              @db = _db.dup
              db.collection = 'jobs'
            end

            def find_by_status(status)
              find_one({'status' => status})
            end

            def find_completed
              find_by_status('completed')
            end

          end # self

        end # Jobs

      end # Helpers

    end # Database

  end # Ubiquity

end # EpisodeEngine

