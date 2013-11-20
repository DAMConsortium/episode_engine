require 'google_drive'
require 'pp'
require 'roo'
require 'zip'


module EpisodeEngine

  module Ubiquity

    class TranscodeSettingsLookup

      #DEFAULT_TRANSCODE_SETTINGS_GOOGLE_WORKBOOK_ID = '0AkcbJWkynMREdEV2RlZFZ0kzQmtsUXNXWXpNcE5RUUE'
      #DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME = 'Transcode Settings'

      class << self

        attr_writer :logger

        def logger
          @logger ||= Logger.new(STDOUT)
        end # logger

        attr_accessor :options
        attr_accessor :workbook_id

        attr_reader :match_log
        attr_reader :match_found

        def log_match_result(log_str)
          logger.debug { "\t#{log_str}" }
          @match_log << log_str
        end

        def build_transcode_settings_table(args = { })
          args = args.dup
          logger.debug { "BUILD TRANSCODE SETTINGS TABLE ARGS: #{PP.pp(args, '')}" }
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
          sheet_name = options.delete(:sheet_name) # { DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME }

          ss = Roo::Google.new(workbook_id, options)
          ss.default_sheet = sheet_name if sheet_name
          rows = ss.parse(:headers => true).drop(1)

          rows
        end # build_trawscode_settings_table_from_google

        def build_transcode_settings_table_from_file(source_file_name, options = { })
          raise Errno::ENOENT, "Source File Not Found. #{source_file_name}" unless File.exists?(source_file_name)

          options = options.dup if options.respond_to?(:dup)
          sheet_name = options.delete(:sheet_name) # { DEFAULT_TRANSCODE_SETTINGS_WORKBOOK_SHEET_NAME }

          # response = Roo::Spreadsheet.open(source_file_name).parse(:headers => true).drop(1)
          # Roo currently creates a row out of the column headers where the keys equal the values. We remove it if is there.
          # first_row = response.first
          # response = response.drop(1) if first_row.keys == first_row.values

          ss = Roo::Spreadsheet.open(source_file_name)
          logger.debug { "Reading Data from Source File.\n#{ss.info}" }
          ss.default_sheet = sheet_name if sheet_name
          rows = ss.parse#(:headers => true)
          if rows.empty?
            logger.info { 'No Rows Were Found When Parsing the Source File.' }
            return { }
          end

          # Roo throws an exception of we use the :headers option when parsing so we do the work ourselves
          # roo-1.11.2/lib/roo/generic_spreadsheet.rb:476:in `each': undefined method `upto' for nil:NilClass (NoMethodError)
          first_row = rows.shift
          rows.map { |r| Hash[ first_row.zip(r) ] }
        end # build_transcode_settings_table_from_file

        def transcode_settings_lookup(values_to_look_for, map)
          match = nil
          @match_log = [ ]
          @match_found = false
          log_match_result("Searching Map For:   #{values_to_look_for}")
          map.each_with_index do |map_entry, idx|
            log_match_result("Searching Map Entry (#{idx + 1}): #{map_entry}")
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
              unless map_entry_value == field_value || map_entry_value == '*'
                log_match_result("\tNo Match For #{field_name} : #{field_value} (#{field_value.class.name}) != #{map_entry_value} (#{map_entry_value.class.name})")
                match_failed = true
                break
              else
                log_match_result("\tMatch For #{field_name} : #{field_value} (#{field_value.class.name}) == #{map_entry_value} (#{map_entry_value.class.name})")
              end
            end
            unless match_failed
              @match_found = true
              match = map_entry
              break
            end
          end
          log_match_result("Match #{match_found ? '' : 'Not '}Found.")
          match
        end # transcode_settings_lookup

        def process_options(options = ())
          file_path = options.delete(:file_path)
          file_path ||= options.delete(:workbook_file_path)

          sheet_name = options.delete(:sheet_name)
          sheet_name ||= options.delete(:workbook_sheet_name)

          google_workbook_id = options.delete(:google_workbook_id) # { DEFAULT_TRANSCODE_SETTINGS_GOOGLE_WORKBOOK_ID }
          google_workbook_username = options.delete(:google_workbook_username)
          google_workbook_password = options.delete(:google_workbook_password)

          transcode_settings_options = { }
          transcode_settings_options[:google_workbook_id] = google_workbook_id if google_workbook_id
          transcode_settings_options[:user] = google_workbook_username if google_workbook_username
          transcode_settings_options[:password] = google_workbook_password if google_workbook_password
          transcode_settings_options[:file_path] = file_path if file_path
          transcode_settings_options[:sheet_name] = sheet_name if sheet_name
          transcode_settings_options
        end # process_options

        def find(data, options = { })
          options = options.dup if options and options.respond_to?(:dup)
          @logger = options.delete(:logger) if options[:logger]

          transcode_settings_options = process_options(options)

          #@transcode_settings_table ||= self.build_transcode_settings_table(workbook_id, options)
          @transcode_settings_table = self.build_transcode_settings_table(transcode_settings_options)
          @transcode_settings_table ||= [ { } ]

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