require 'curb'
require 'json'

class ResultSweeperJob < ApplicationJob
  queue_as :default

  def perform

    
    puts "Puts"
    logger.debug "logger debug"
    logger.info "logger info"
    logger.warn "logger warn"
    logger.error "logger error"
    logger.fatal "logger fatal"

    return
    
    results = Result.where(status: 0).limit(1)
    result_array = results.to_a # Cause Rails is weird
    results.update_all status: 1 # mark all as owned
    logger.debug "!!!!!!!!!!!!!!!"
    puts "!!!!!!!!!!!"
    result_array.each do |result|
      result.request.update status: 1
      amount = count_result result
      if !amount
        logger.info "!amount"
        result.update status: -1
      elsif amount >= 19 && result.precision == 'month'
        # Destroy Result, create Daily
        logger.info "create daily"
        create_daily_requests result
      else
        result.update amount: amount, status: 2
        logger.info "found #{amount} from #{result.request.query}, #{result.start_date} - #{result.end_date}"
        check_complete_request result.request
        sleep 0.5
      end
    end
    #perform
  end

  def create_daily_requests result
    request = result.request

    loop_start_date = result.start_date
    loop_end_date = result.end_date

    while loop_start_date < loop_end_date
      result_start_date = loop_start_date
      result_end_date = loop_start_date.next_day
      request.results.create(start_date: result_start_date, end_date: result_end_date, amount: 0, precision: 'day', status: 0)
      loop_start_date = result_end_date
    end
    result.update status: 3
  end


  def check_complete_request request
    unless request.results.any?{|result| result.status != 2}
      request.update status: 2
      ResponseCompleteMailer.success(request).deliver_now
    end
  end

  # Returns estimate count on OK, false on error
  def count_result result
    request = result.request
    url = 'https://groups.google.com/forum/fsearch?appversion=1&hl=en&authuser=0'
    query = "#{request.query} after:#{result.start_date.to_s} before:#{result.end_date.to_s}"
    authstring = request.authstring.blank? ? ENV['default-authstring'] : request.authstring
    cookie = request.cookie.blank? ? ENV['default-cookie'] : request.cookie
    payload = "7|3|12|https://groups.google.com/forum/|D2FD55322ACD18E1E5E0D2074EB623A5|5m|#{authstring}|_|getMatchingMessages|5t|i|I|1u|5n|#{query}|1|2|3|4|5|6|6|7|8|9|9|10|11|12|0|0|20|0|0|"

    # Using Curb
    post = Curl.post(url, payload) do |curl|
      curl.headers['Content-Type'] = 'text/x-gwt-rpc; charset=utf-8'
      curl.headers['X-GWT-Permutation'] = 'fdsds'
      curl.headers['X-GWT-Module-Base'] = 'https://groups.google.com/forum/'
      curl.headers['Cookie'] = cookie
    end

    output = post.body_str
    if output.first(4) == '//OK'
      output.slice!(0,4)
      output = output.tr("'", '"')
      # TODO Add error handling here
      output_array = JSON.parse(output)
      # Because the google groups output has a second array in here
      output_array.each do |value|
        if value.class==Array
          array_length = value.length
          amount = amount_from_google_groups_length array_length
          return amount
        end
      end
    else
      puts output
      return false
    end
  end


  def amount_from_google_groups_length array_length
    if array_length <= 4
      0
    else
      ((array_length - 23) / 7).to_i
    end
  end

end
