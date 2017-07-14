module Periods
  module Calculator

    VALID_PERIODS = [ :annually, :quarterly, :monthly, :weekly, :daily, :semi_annually]

    def advance(d, options)
      #based on http://api.rubyonrails.org/v2.3.11/classes/ActiveSupport/CoreExtensions/Date/Calculations.html#M000918
      options = options.dup
      d = d >> options.delete(:annually) * 12 if options[:annually]
      d = d >> options.delete(:semi_annually) * 6 if options[:semi_annually]
      d = d >> options.delete(:quarterly) * 3 if options[:quarterly]
      d = d >> options.delete(:monthly)     if options[:monthly]
      d = d +  options.delete(:weekly) * 7  if options[:weekly]
      d = d +  options.delete(:daily)       if options[:daily]
      d
    end

    def calculate_next_date(options = {})
      start_date  = options[:start_date] || Date.today
      period = ( options[:period] || :monthly ).to_sym
      end_date = options[:end_date]

      raise ArgumentError.new("period should be within #{VALID_PERIODS}") unless VALID_PERIODS.include?(period)
      date = calculate_no_of_periods(start_date,Date.today,period)[:date]
      return (end_date && (date > end_date)) ? nil : date
    end

    def calculate_no_of_periods(start_date,end_date,period)
      i = 1
      date = advance(start_date, { period => i })
      until date > end_date do
        i += 1
        date = advance(start_date, { period => i })
      end
      { date: date , count: i }
    end

    def calculate_total_value(recurring_donation)
      end_date = recurring_donation.end_date || Date.today.next_year.prev_day
      period = recurring_donation.period.to_sym
      no_of_periods = calculate_no_of_periods(Date.today,end_date,period)[:count]
      total_amount = recurring_donation.total_amount_per_period * no_of_periods
      { no_of_periods: no_of_periods , total_amount: total_amount, end_date: end_date }
    end
  end
end