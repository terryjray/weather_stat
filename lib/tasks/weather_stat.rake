require 'csv'
require 'rest-client'

desc 'Weather Stats - 5yr average by city by date'
task :weather_averages, [:city_state_csv] => :environment do |t, args|

  unless  args[:city_state_csv]
    puts "syntax: rake weather_stat:history_by_date <csv>"
    exit -1
  end

  city_states = []
  CSV.foreach(args[:city_state_csv]) do |row|
    city_states << row
  end

  city_states.each do |row|

    # start in Nov 1, go forward two weeks until reaching March 1st
    year = 2015
    month = 11
    day = 1
    city = row[0].strip.gsub(' ','_')
    state = row[1].strip
    current_date = Date.new(year, month, day)
    api_key = ENV['API_KEY']
    base_url = "http://api.wunderground.com/api/#{api_key}/history_"

    if city == '' || state == ''
      pp "Skipping #{city},#{state}"
      next
    end

    CSV.open("#{state}_#{city}.csv", "w") do |csv|
      csv << ["day of year", "min temp", "max temp", "mean windspeed", "min vis", "max vis", "percip in"]
      until current_date >= Date.new(2016,3,1) do
        year = current_date.year
        month = current_date.mon
        day = current_date.mday

        min_temp_avg = 0
        max_temp_avg = 0
        mean_wsp_avg = 0
        min_vis_avg = 0
        max_vis_avg = 0
        percip_avg = 0

        (0..4).each do |n|
          sample_yr = year - n
          sample_dt = Date.new(sample_yr.to_i, month.to_i, day.to_i)
          sample_dt_str = sample_dt.strftime("%Y%m%d")
          url = "#{base_url}#{sample_dt_str}/q/#{state}/#{city}.json"
          puts url
          next
          response = RestClient.get url
          json = JSON.parse(response.body)
          # get the high and low for the day based on each hourly measurement
          summary = json['history']['dailysummary'].first
          min_temp_avg += summary['mintempi'].to_f
          max_temp_avg += summary['maxtempi'].to_f
          mean_wsp_avg += summary['meanwindspdi'].to_f
          min_vis_avg += summary['minvisi'].to_f
          max_vis_avg += summary['maxvisi'].to_f
          percip_avg += summary['precipi'].to_f
        end # do 5 year avg

        csv << [ "#{month}-#{day}", (min_temp_avg/5), (max_temp_avg/5), (mean_wsp_avg/5), (min_vis_avg/5), (max_vis_avg/5), (percip_avg/5)]
        pp "finished averages for #{current_date.to_s}"
        current_date += 2.weeks
        # pause so we don't exceed our rate limit
        sleep(1)
      end # until
    end # csv open
  end # city state loop
end
