require 'google_drive'
require 'pp'
require 'roo'
require 'zip'


module EpisodeEngine

  module Ubiquity

    class TranscodeSettingsLookup

      DEFAULT_TRANSCODE_SETTINGS_GOOGLE_WORKBOOK_ID = '0AkcbJWkynMREdEV2RlZFZ0kzQmtsUXNXWXpNcE5RUUE'
      DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME = 'Transcode Settings'

      class << self

        attr_writer :logger

        def logger
          @logger ||= Logger.new(STDOUT)
        end # logger

        attr_accessor :options
        attr_accessor :workbook_id

        def build_transcode_settings_table(args = { })
          args = args.dup
          #puts "BUILD TRANSCODE SETTINGS TABLE ARGS: #{PP.pp(args, '')}"
          google_workbook_id = args.delete(:google_workbook_id)
          file_path = args.delete(:file_path)

          options = args
          if google_workbook_id
            table = build_transcode_settings_table_from_google(google_workbook_id, options)
          elsif file_path
            table = build_transcode_settings_table_from_file(file_path, options)
          else
            logger.error { "Failed to Build Transcode Settings Table. Arguments: #{args}" }
            table = [ ]
          end
          table
        end # build_transcode_setting_table

        def build_transcode_settings_table_from_google(workbook_id, options = { })
          options = options.dup if options.respond_to?(:dup)
          sheet_name = options.delete(:sheet_name) { DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME }

          ss = Roo::Google.new(workbook_id, options)
          ss.default_sheet = sheet_name
          rows = ss.parse(:headers => true).drop(1)

          rows
        end # build_trawscode_settings_table_from_google

        def build_transcode_settings_table_from_file(source_file_name, options = { })
          abort "Source File Not Found. #{source_file_name}" unless File.exists?(source_file_name)

          options = options.dup if options.respond_to?(:dup)
          sheet_name = options.delete(:sheet_name) { DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME }

          # response = Roo::Spreadsheet.open(source_file_name).parse(:headers => true).drop(1)
          # Roo currently creates a row out of the column headers where the keys equal the values. We remove it if is there.
          # first_row = response.first
          # response = response.drop(1) if first_row.keys == first_row.values

          ss = Roo::Spreadsheet.open(source_file_name)
          logger.debug { "Reading Data from Source File.\n#{ss.info}" }
          ss.default_sheet = sheet_name
          rows = ss.parse#(:headers => true)
          abort 'Now Rows Were Found When Parsing the Source File.' if rows.empty?

          # Roo throws an exception of we use the :headers option when parsing so we do the work ourselves
          # roo-1.11.2/lib/roo/generic_spreadsheet.rb:476:in `each': undefined method `upto' for nil:NilClass (NoMethodError)
          first_row = rows.shift
          rows.map { |r| Hash[ first_row.zip(r) ] }
        end

        def transcode_settings_lookup(values_to_look_for, map)
          logger.debug { "Searching Map For:   #{values_to_look_for}" }
          match = nil
          map.each do |map_entry|
            logger.debug { "Searching Map Entry: #{map_entry}" }
            match_failed = nil
            values_to_look_for.each do |field_name, field_value|
              map_entry_value = map_entry[field_name]
              if map_entry_value.is_a?(String)
                map_entry_value = map_entry_value[1..-2] if map_entry_value.start_with?('"')
                field_value = field_value.to_s if field_value === true || field_value === false
              else
                if field_value.is_a?(String)
                  map_entry_value = map_entry_value.to_s
                end
              end
              #field_value = field_value.to_s.downcase
              unless map_entry_value == field_value
                logger.debug { "\tNo Match For #{field_name} : #{field_value} (#{field_value.class.name}) != #{map_entry_value} (#{map_entry_value.class.name})" }
                match_failed = true
                break
              else
                logger.debug { "\tMatch For #{field_name} : #{field_value} (#{field_value.class.name}) == #{map_entry_value} (#{map_entry_value.class.name})"  }
              end
            end
            unless match_failed
              match = map_entry
              break
            end
          end
          match
        end # transcode_settings_lookup

        def find(data, options = { })
          options = options.dup if options and options.respond_to?(:dup)
          @logger = options.delete(:logger) if options[:logger]

          file_path = options.delete(:file_path)

          google_workbook_id = options.delete(:google_workbook_id) { DEFAULT_TRANSCODE_SETTINGS_GOOGLE_WORKBOOK_ID }
          google_workbook_username = options.delete(:google_workbook_username)
          google_workbook_password = options.delete(:google_workbook_password)

          transcode_settings_options = { }
          transcode_settings_options[:google_workbook_id] = google_workbook_id if google_workbook_id
          transcode_settings_options[:user] = google_workbook_username
          transcode_settings_options[:password] = google_workbook_password
          transcode_settings_options[:file_path] = file_path if file_path

          #@transcode_settings_table ||= self.build_transcode_settings_table(workbook_id, options)
          @transcode_settings_table = self.build_transcode_settings_table(transcode_settings_options)
          data_to_find = { }
          data.each { |k,v| data_to_find[k.to_s] = v }
          unused_common_fields = data_to_find.keys - @transcode_settings_table.first.keys
          #puts 'Unused Common Field: '
          #pp unused_common_fields
          cm = data_to_find.delete_if { |k,_| unused_common_fields.include?(k) }
          #puts "Data to match:"
          #pp cm
          record = self.transcode_settings_lookup(cm, @transcode_settings_table) || { }
          record
        end

      end # self

    end # TranscodeSettingsLookup


  end # Ubiquity

end # EpisodeEngine