#require 'active_support/all'
require 'active_support/core_ext'
#require 'active_support/core_ext/date'
#require 'active_support/core_ext/date_time'

module DateTimeHelper

  # Processes common time periods and turns them into from to dates.
  # if a to date is not given then it will be auto populated with the from_date 
  #
  # @param [String] from_date (Required) 
  #   in the last hour  - Now - 1 hour
  #   this hour         - The beginning of the hour
  #   last hour         - The beginning of the previous hour
  #   in the last day   - Now - 24 hours
  #   today             - The beginning of the day
  #   yesterday         - The beginning of yesterday
  #   in the last week  - Now - 1 week
  #   this week         - The beginning of the week
  #   last week         - The beginning of last week
  #   in the last month - Now - 1 month
  #   this month        - The beginning of the month
  #   last month        - The beginning of last month
  #   this quarter      - The beginning of the quarter
  #   last quarter      - The beginning of last quarter
  #   this half         - The beginning of this half
  #   last half         - The beginning of the last half
  #   in the last year  - Now - 1 year
  #   this year         - The beginning of the year
  #   last year         - The beginning of last year
  #   epoch             - Any epoch time made up of 10 digits
  #   YYYYMMDDHHMM      - date string to the minute
  #   Any valid date value parseable by DateTime.parse
  #
  # @param [String] to_date (from_date)
  #   in the last hour  - Now
  #   this hour         - The end of the hour
  #   last hour         - The end of the previous hour
  #   in the last day   - Now
  #   today             - The end of the day
  #   yesterday         - The end of yesterday
  #   in the last week  - Now
  #   this week         - The end of the week
  #   last week         - The end of last week
  #   in the last month - Now
  #   this month        - The end of the month
  #   last month        - The end of last month
  #   this quarter      - The end of the quarter
  #   last quarter      - The end of last quarter
  #   this half         - The end of this half
  #   last half         - The end of the last half
  #   in the last year  - Now
  #   this year         - The end of the year
  #   last year         - The end of last year
  #   epoch             - Any epoch time made up of 10 digits
  #   YYYYMMDDHHMM      - date string to the minute
  #   Any valid date value parseable by DateTime.parse
  #
  # @return [Array<DateTime>] [ from_date, to_date ]
  def self.process_range(from_date, to_date = nil)
    from_date_str = from_date.to_s.downcase.gsub('_', ' ')
    to_date_str = to_date ? to_date.to_s.downcase.gsub('_', ' ') : nil

    case from_date_str
      when 'in the last hour' # This case diverges the main pattern
        _from_date = DateTime.current - 1.hour
        to_date_str = 'now'
      when 'this hour'
        _from_date = DateTime.current.beginning_of_hour
        to_date_str = from_date_str unless to_date_str
      when 'last hour', 'prev hour'
        _from_date = (DateTime.current - 1.hour).beginning_of_hour
        to_date_str = from_date_str unless to_date_str
      when 'in the last day'
        _from_date = (DateTime.current - 24.hour)
        to_date_str = 'now'
      when 'today'
        _from_date = DateTime.current.beginning_of_day
        to_date_str = from_date_str unless to_date_str
      when 'yesterday'
        _from_date = DateTime.yesterday.beginning_of_day
        to_date_str = from_date_str unless to_date_str
      when 'in the last week'
        _from_date = DateTime.current - 1.week
        to_date_str = 'now'
      when 'this week'
        _from_date = DateTime.current.beginning_of_week
        to_date_str = from_date_str unless to_date_str
      when 'last week'
        _from_date = DateTime.current.prev_week.beginning_of_week
        to_date_str = from_date_str unless to_date_str
      when 'in the last month'
        _from_date = DateTime.current - 1.month
        to_date_str = 'now'
      when 'this month'
        _from_date = DateTime.current.beginning_of_month
        to_date_str = from_date_str unless to_date_str
      when 'last month'
        _from_date = DateTime.current.prev_month.beginning_of_month
        to_date_str = from_date_str unless to_date_str
      when 'this quarter'
        _from_date = DateTime.current.beginning_of_quarter
        to_date_str = from_date_str unless to_date_str
      when 'last quarter'
        _from_date = DateTime.current.prev_quarter.beginning_of_quarter
        to_date_str = from_date_str unless to_date_str
      when 'this half'
        if DateTime.now.month < 7
          _from_date = DateTime.current.beginning_of_year
        else
          _from_date = DateTime.parse('July 1')
        end
        to_date_str = from_date_str unless to_date_str
      when 'last half'
        if DateTime.now.month < 7
          _from_date = (DateTime.current - 1.year).beginning_of_year
        else
          _from_date = (DateTime.parse('July') - 1.year)
        end
        to_date_str = from_date_str unless to_date_str
      when 'in the last year' # This case diverges the main pattern
        _from_date = DateTime.current - 1.year
        to_date_str = 'now'
      when 'this year'
        _from_date = DateTime.current.beginning_of_year
        to_date_str = from_date_str unless to_date_str
      when 'last year', 'prev year'
        _from_date = DateTime.current.prev_year.beginning_of_year
        to_date_str = from_date_str unless to_date_str
      when /^\d{10}$/ # epoch
        _from_date = DateTime.strptime(from_date_str, '%s')
      when /^\d{12}$/ # Date string to the minute YYYYMMDDHHMM
        _from_date = DateTime.parse(from_date_str.insert(8, 'T'))
      else
        _from_date = DateTime.parse(from_date_str)
    end # case from_date_str

    case to_date_str
      when 'now'
        _to_date = DateTime.current
      when 'this hour'
        _to_date = DateTime.current.end_of_hour
      when 'last hour', 'prev hour'
        _to_date = (DateTime.current - 1.hour).end_of_hour
      when 'today'
        _to_date = DateTime.current.end_of_day
      when 'yesterday'
        _to_date = DateTime.yesterday.end_of_day
      when 'this week'
        _to_date = DateTime.current.end_of_week
      when 'last week'
        _to_date = DateTime.current.prev_week.end_of_week
      when 'this month'
        _to_date = DateTime.current.end_of_month
      when 'last month'
        _to_date = DateTime.current.prev_month.end_of_month
      when 'this quarter'
        _to_date = DateTime.current.end_of_quarter
      when 'last quarter'
        _to_date = DateTime.current.prev_quarter.end_of_quarter
      when 'this half'
        if DateTime.now.month < 7
          _from_date = DateTime.parse('June').end_of_month
        else
          _from_date = DateTime.current.end_of_year
        end
      when 'last half'
        if DateTime.now.month < 7
          _from_date = (DateTime.parse('July') - 1.year).end_of_month
        else
          _from_date = (DateTime.current - 1.year).end_of_year
        end
      when 'this year'
        _to_date = DateTime.current.end_of_year
      when 'last year'
        _to_date = DateTime.current.prev_year.end_of_year
      when /^\d{10}$/ # epoch
        _to_date = DateTime.strptime(to_date_str, '%s')
      when /^\d{12}$/ # YYYYMMDDHHMM
        _to_date = DateTime.parse(to_date_str.insert(8, 'T'))
      else
        _to_date = DateTime.parse(to_date_str)
    end # case to_date_str

    return _from_date, _to_date
  end # self.process_range

end # DateTimeHelper
