require 'csv'

class GTFS < Crawler
  def initialize
    super

    @gtfsFolder = Dir.pwd + "/tmp/gtfs"
    Dir.mkdir(@gtfsFolder) unless File.exists?(@gtfsFolder)
  end

  def dummy
    # Generate a dummy agency.txt and calender.txt
    if not File.exist?("#{@gtfsFolder}/agency.txt")
      puts "Create agency.txt"
      File.open("#{@gtfsFolder}/agency.txt", 'wb') do |csv_agency|
        csv_agency << "agency_id, agency_name,agency_url,agency_timezone\nsbb,SBB,http://www.ssb.ch,Europe/Zurich"
      end
    end
    if not File.file?("#{@gtfsFolder}/calendar.txt")
      puts "Create calender.txt"
      File.open("#{@gtfsFolder}/calendar.txt", 'wb') do |csv_calender|
        csv_calender << "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nWD,1,1,1,1,1,0,0,20130101,20131231"
      end
    end
  end

  def stops
    # Generate stops.txt
    # Individual location where vehicles pick up or drop off passangers
    puts "Start exporting stops.txt ..."

    sql_station = 'SELECT id, name, y AS lat, x AS long FROM station'  
    rows = @db.execute(sql_station)
    CSV.open("#{@gtfsFolder}/stops.txt", 'wb') do |csv|
      # CSV Header
      csv << ["stop_id", "stop_name", "stop_lat", "stop_lon"]
      rows.each do |station|
        stop_id = station["id"]
        stop_name = station["name"]
        stop_lat = station["lat"]
        stop_lon = station["long"]

        csv << [stop_id, stop_name, stop_lat, stop_lon]
      end
    end
    puts "finished\n"
  end # end stops

  def trips
    # Generate routes.txt
    # Transit routes. A route is a group of trips that are displayed to riders as a single service.
    puts "Start exporting routes.txt ..."

    # Mapping of vehicle to type to GTFS route_type
    $MAP_VEHICLETYPE_GTFS_ROUTETYPE = {
      'tram'  => 0,
      'train' => 2,
      'bus'   => 3,
      'boat'  => 4,
      'cable' => 5,
      'funicular' => 7,
    }

    # A route must have same start and stop station and the same name
    sql_route = 'SELECT vehicle.vehicle_name, station_start, station1.name as station_start_name, station_end, station2.name as station_end_name, vehicle_type FROM vehicle left join station as station1 on station1.id = vehicle.station_start left join station as station2 on station2.id = vehicle.station_end GROUP BY vehicle.vehicle_name, vehicle.station_start, station_end'
    sql_trips = 'SELECT vehicle_id FROM vehicle WHERE station_start = ? AND station_end = ? AND vehicle_name = ?'
    rows = @db.execute(sql_route)
    k = 1;
    CSV.open("#{@gtfsFolder}/routes.txt", 'wb') do |csv_routes|
      CSV.open("#{@gtfsFolder}/trips.txt", 'wb') do |csv_trips|
        # routes.txt header
        csv_routes << ["route_id", "route_short_name", "route_long_name","route_type"]
        # trips.txt header
        csv_trips << ["route_id", "service_id", "trip_id"]

        rows.each do |route|
          # routes.txt parameters
          route_id = k;
          route_short_name = route['vehicle_name']
          route_long_name = "From #{route['station_start_name']} to #{route['station_end_name']}"
          route_type =  $MAP_VEHICLETYPE_GTFS_ROUTETYPE[route['vehicle_type']]
          if route_type  == nil
            puts "No route_type for #{route['vehicle_type']} \n"
          end

          # Write route to routes.txt
          csv_routes << [route_id, route_short_name, route_long_name,route_type]

          # Find all trips for specifc route
          trips = @db.execute(sql_trips, route['station_start'], route['station_end'], route['vehicle_name'])
          trips.each do |trip|
            # trips.txt parameters
            # TODO: weekdays assumed
            service_id = "WD";
            trip_id = trip['vehicle_id']

            # Write trip tip
            csv_trips << [route_id, service_id, trip_id]
          end
          k = k + 1
        end
      end #csv_trips
    end # end csv_route
    puts "finished\n"
  end # end trips

  def stoptimes
    # Generate stop_time.txt
    # Sets for all trips the stops and their sequence
    puts "Start exporting stop_times.txt ..."
    CSV.open("#{@gtfsFolder}/stop_times.txt", 'wb') do |csv_stops|
      # routes.txt header
      csv_stops << ["trip_id", "arrival_time", "departure_time","stop_id", "stop_sequence"]

      # SQL Queries
      sql_trips = 'SELECT vehicle_id, time_start, time_end FROM vehicle'
      sql_stops = 'SELECT station_id, time(departure_time) as departure_time, (time(departure_time) < time(:startTime)) as nextday FROM timetable WHERE vehicle_id = :id ORDER BY time(departure_time, :endTime)'   

      trips =  @db.execute(sql_trips)
      trips.each do |trip|
        trip_id = trip['vehicle_id']
        startTime = trip['time_start']
        endTime  = "-#{trip['time_end']}:01"

        seq = 1
        stops = @db.execute(sql_stops, "id" => trip_id,"startTime" => startTime, "endTime" => endTime)
        stops.each do |stop|
          if stop['nextday'] == 1
            time = stop['departure_time'].split(":")
            hours = time[0].to_i + 24
            arrival_time = "#{hours}:#{time[1]}:#{time[2]}"
          else 
            arrival_time = stop['departure_time']
          end
          departure_time = arrival_time
          stop_id = stop['station_id']
          stop_sequence = seq

          # Write to stop_times.txt
          csv_stops << [trip_id, arrival_time, departure_time, stop_id, stop_sequence]
          seq = seq + 1;
        end
      end
    end
    puts "finished\n"
  end # end stoptimes
end
