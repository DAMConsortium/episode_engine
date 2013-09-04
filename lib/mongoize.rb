module Mongoize
  # A utility module to process hash keys so that unsafe characters and symbols
  # will be changed to a parseable value that can be restored once retrieved from mongo
  #
  #
  # i = Mongoize.to_mongo({ :name => 'value' })
  # # => { '!sym!name' => 'value'}
  # o = Mongoize.from_mongo(i)
  # # => { :name => 'value' }
  #
  class Common

    def self.default_params
      @default_params ||= {
        invalid_chr_pattern: /^\$|\./ , # First character is a $ or any periods or spaces
        recursive: true,
        prefix: '!',
        suffix: '!',
        symbol_indicator: 'sym',
      }
    end # default_params

    def self.default_params=(value)
      @default_params = value
    end # default_params=

    def self.filter_hash(search_for = @default_params, search_in)
      hash_out = { }
      search_for.each { |parameter, default_value|
        case parameter
          when Symbol, String, Integer
            hash_out[parameter] = search_in.fetch(parameter, default_value) if search_in.has_key? parameter or !default_value.nil?
          when Hash, Array
            name, default_value = parameter.dup.shift
            hash_out[name] = search_in.fetch(name, default_value)
        end
      }
      hash_out
    end # filter_hash

    def self.to_mongo(value_in, params = { })
      case value_in
        when Array
          return value_in.dup.map { |v| to_mongo(v, params) }
        when Hash
          params = filter_hash(default_params, params)
          v = process_value_to_mongo(value_in, params[:invalid_chr_pattern], params[:prefix], params[:suffix], params[:symbol_indicator], params[:recursive])
          return v
        else
          return value_in
      end
    end # to_mongo

    def self.from_mongo(value_in, params = { })
      case value_in
        when Array
          return value_in.dup.map { |v| from_mongo(v, params) }
        when Hash
          params = filter_hash(default_params, params)
          v = process_value_from_mongo(value_in, params[:prefix], params[:suffix], params[:symbol_indicator], params[:recursive])
          return v
        else
          return value_in
      end
    end # from_mongo

    def self.process_value_to_mongo(value_in, sub_pattern, prefix, suffix, symbol_indicator, recursive)
      case value_in
        when Array
          return value_in.dup.map { |value| process_value_to_mongo(value, sub_pattern, prefix, suffix, symbol_indicator, recursive) } if recursive
          return value_in
        when Hash
          _symbol_indicator =  "#{prefix}#{symbol_indicator}#{suffix}"
          value_out = { }
          value_in.each { |key, value|
            key = "#{_symbol_indicator}#{key.to_s}" if key.is_a? Symbol
            # Ran into an issue where key was nil so we do a is_a?(String) check
            key = key.gsub(sub_pattern) { |s| "#{prefix}#{s.ord.to_s}#{suffix}" } if key.is_a?(String)
            value = process_value_to_mongo(value, sub_pattern, prefix, suffix, symbol_indicator, recursive) if recursive and (value.is_a?(Hash) or value.is_a?(Array))
            value_out[key] = value
          }
          return value_out
        else
          return value_in
      end
    end # process_hash_to_mongo

    def self.process_value_from_mongo(value_in, prefix, suffix, symbol_indicator, recursive)
      case value_in
        when Array
          return value_in.dup.map { |value| process_value_from_mongo(value, prefix, suffix, symbol_indicator, recursive) } if recursive
          return value_in
        when Hash
          _symbol_indicator =  "#{prefix}#{symbol_indicator}#{suffix}"
          symbol_indicator_len = _symbol_indicator.length
          sub_pattern = /#{prefix}([0-2]*[0-9]{1,2})#{suffix}/
          value_out = { }
          value_in.each { |key, value|
            key = key.gsub(sub_pattern) { |s| $1.to_i.chr }
            key = key[(symbol_indicator_len)..-1].to_sym if key.start_with? "#{_symbol_indicator}"
            value = process_value_from_mongo(value, prefix, suffix, symbol_indicator, recursive) if recursive and (value.is_a?(Hash) or value.is_a?(Array))
            value_out[key] = value
          }
          return value_out
        else
          return value_in
      end
    end # process_value_from_mongo

  end # Common

  def self.to_mongo(*args); Common.to_mongo(*args) end
  def self.from_mongo(*args); Common.from_mongo(*args) end

end # Mongoize