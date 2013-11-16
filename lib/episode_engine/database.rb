require 'mongo'
module EpisodeEngine

  class Database

    DEFAULT_DATABASE_NAME = 'episode_engine'

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

        @col = db.collection(args[:collection_name]) if args[:collection_name]
      end

      def collection=(collection_name)
        @col = db.collection(collection_name)
      end # collection

      def find_all
        find({ })
      end # find_all

      def find(selector, options = { });
        _selector = Mongoize.to_mongo(selector, :invalid_chr_pattern => /^\./)
        result = Mongoize.from_mongo(col.find(_selector, options).to_a)
        result
      end # find

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
            db.find_one('_id' => BSON::ObjectId(id))
          end # find_by_id

          def find(*args)
            db.find(*args)
          end # find

          def find_all
            self.find({ })
          end # find_all

          def process_query_pagination_parameters(args = { })
            args = args.dup
            limit = search_hash!(args, :limit) || 100
            start = search_hash!(args, :start)
            if start
              start = start.to_i
              skip_default = start > 1 ? start - 1 : 0
            else
              skip_default = 0
            end
            skip = search_hash!(args, :skip) || skip_default
            { :skip => skip.to_i, :limit => limit.to_i }
          end # process_query_pagination_parameters


        end # self


      end # Common

      class Jobs < Common
        class << self

          def db=(_db)
            @db = _db.dup
            db.collection = 'jobs'
          end

          def insert(host, id, record = { })
            record['type'] = 'job'
            record['host'] = host
            record['history'] = { }
            record['status'] = 'new'
            db.insert(record)
          end # insert

        end # self
      end # Jobs

      class Requests < Common

        METHOD_TO_ACTION = { 'POST' => :create, 'PUT' => :update, 'DELETE' => :delete, 'GET' => :retrieve }
        class << self

          def db=(_db)
            @db = _db.dup
            db.collection = 'requests'
          end # db=

          def insert(request_detail, subject = nil, system = :episode)
            record = { }
            record['type'] = 'request'
            record['subject'] = subject
            record['system'] = system
            record['action'] = METHOD_TO_ACTION[request_detail[:request_method]]
            record['status'] = 'new'
            record['content'] = request_detail

            record['created_at'] =
                record['modified_at'] = Time.now.to_i

            id = db.insert(record)
            id
          end # insert

          def update_status(request_id, status, record = { })
            record['status'] = status
            update(request_id, record)
          end

          def set_to_completed(request_id, record = { })
            record['completed'] = true
            update_status(request_id, 'completed', record)
          end

          def find_by_date_and_status(date_from = nil, date_to = nil, status = :all, options = { })
            #status = args[:status]
            #date_from = args[:date_from]
            #date_to = args[:date_to]
            #

            options.merge!(process_query_pagination_parameters(options))
            options[:sort] ||= 'created_at'

            selector = { }
            if date_from
              _date_from, _date_to = DateTimeHelper.process_range(date_from, date_to)
              selector['created_at'] = { '$gte' => _date_from.to_i, '$lte' => _date_to.to_i }
            end

            job_status = status.downcase.to_sym
            logger.debug { "Searching for #{job_status} jobs. From: #{date_from} (#{_date_from}) To: #{date_to} (#{_date_to})\n\tSelector: #{selector}\n\tOptions: #{options}" }
            unknown_job_status = false
            case job_status
              when :running
                # Not Completed
                selector['completed'] = false
              when :completed
                # Completed
                selector['completed'] = true
              when :failed
                # Completed And Failed
                selector['completed'] = true
                selector['success'] = false
              when :success, :successful
                # Completed and Successful
                selector['completed'] = true
                selector['success'] = true
              when :cancelled, :canceled
                # Future Implementation
              when :all
                # All regardless of status
              else
                _response = { :error => { :message => "Unknown Job Status. '#{job_status}'" } }
                unknown_job_status = true
            end

            find(selector, options)
          end # find_by_status_and_date

        end # self

      end # Requests

    end # Helpers

  end # Database

end # EpisodeEngine
