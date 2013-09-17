require 'yaml'
require 'mongo'

module EpisodeEngine

  module Ubiquity

    class SubmissionManager

      class MongoDB

        DEFAULT_ARGUMENTS = {
          :host => nil,
          :port => nil,
          :database_name => 'ubiquity',
          :collection_name => 'episode-engine-submissions',
          :connection_options => { }
        }

        def initialize(args = { })

          args = DEFAULT_ARGUMENTS#.merge(args.dup)

          #@connection_options ||= { :safe => true }
          @connection_options = args[:connection_options]
          @database_name = args[:database_name]
          @collection_name = args[:collection_name]
          @host = args[:host]
          @port = args[:port]

          @connection = Mongo::Connection.new(@host, @port, @connection_options)
          @db = @connection[@database_name]
          @coll = @db[@collection_name]
        end # initialize

        def add(id, source_full_file_path, message_header, message_payload, host, ubiquity_job_id = nil)
          doc = {
              '_id' => id,
              'source_full_file_path' => source_full_file_path,
              'message_header' => message_header,
              'message_payload' => message_payload,
              'host' => host,
              'ubiquity_job_id' => ubiquity_job_id,
              'created_at' => Time.now.to_i,
              'modified_at' => Time.now.to_i
          }
          #@coll.insert(doc, :safe => { :j => true })
          @coll.insert(doc)
        end # add

        def find(*args)
          @coll.find(*args).to_a
        end # find

        def get(id)
          @coll.find_one('_id' => id)
        end # get

        def get_all
          @coll.find.to_a
        end # get_all

        def remove(id)
          @coll.remove({ '_id' => id })
        end # remove

        def update(*args)
          @coll.update(*args)
        end # update

      end # MongoDB

      attr_accessor :logger, :db_name, :db

      def initialize(*args)

        set_instance_variables(args) unless args.nil?

        initialize_db

      end # initialize

      def set_instance_variables(*args)
        args[0].each do |k,v|
          if k.is_a? Hash
            k.each { |key,val| instance_variable_set("@#{key}", val) }
          else
            instance_variable_set("@#{k}", val) unless val.nil?
          end
        end unless args.nil? # args[0].each
      end # set_instance_variables

      def initialize_db(*args)
        #@db ||= SQLite.new(args)
        @db ||= MongoDB.new(args)
      end # initialize_db

      # @param [String]
      # @return [Boolean]
      def submission_add(id, source_full_file_path, message_header, message_payload, host, ubiquity_job_id = nil)
        @db.add(id, source_full_file_path, message_header, message_payload, host, ubiquity_job_id)
      end # submission_add

      # @param [String] id
      # @return [Array]
      def submission_get(id)
        @db.get(id)
      end # submission_get

      # @return [Array(Hash)]
      def submission_get_all
        @db.get_all
      end

      def submission_get_by_ubiquity_job_id(id)
        @db.find('ubiquity_job_id' => id)
      end # submission_get_by_ubiquity_job_id

      def submission_get_all_not_published
        @db.find('published' => { '$ne' => true })
      end #

      # @param [String] id
      # @return [Boolean]
      def submission_remove(id)
        @db.remove(id)
      end # submission_remove

      def submission_published(id)
        @db.update({ '_id' => id }, { '$set' => { 'published' => true, 'modified_at' => Time.now.to_i }})
      end # submission_complete

    end # SubmissionManager

  end # EpisodeEngine

end # UDAMUtils