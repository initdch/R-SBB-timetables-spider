require 'csv'

class GTFS < Crawler
  def initialize
    super

    @gtfsFolder = Dir.pwd + "/tmp/gtfs"
  end

  def parse
      # Generate stops.txt
      # Individual location where vehicles pick up or drop off passangers
            
      sql_station = 'SELECT id, name, y AS lat, x AS long FROM station'  
      rows = @db.execute(sql_station)
      CSV.open("#{@gtfsFolder}/stop.txt", 'wb') do |csv|
        # CSV Header
        csv << ["stop_id", "stop_name", "stop_lat", "stop_lon"]
        rows.each do |station|
          stop_id = station["id"]
          stop_name = station["name"].gsub("\n",'')
          stop_lat = station["lat"]
          stop_lon = station["long"]
          
          csv << [stop_id, stop_name, stop_lat, stop_lon]
        end
      end
      
      # Generate routes.txt
      # Transit routes. A route is a group of trips that are displayed to riders as a single service.
      
      # A route must have same start and stop station and the same name
      sql_route = 'SELECT vehicle_name, station_start, station_stop FROM vehicle GROUP BY vehicle_name, station_start, station_stop'
      rows = @db.execute(sql_route)
      k = 0;
      rows.each do |route|
        route_id = k;
        route_short_name = route['vehicle_name']
        route_long_name = "#{route['vehicle_name']} from #{route['station_start']} to #{route['station_stop']}"
        $MAP_VEHICLETYPE_STATIONTYPE[route['vehicle_name']]
        
        k = k + 1;
      end
  end # end parse
end
