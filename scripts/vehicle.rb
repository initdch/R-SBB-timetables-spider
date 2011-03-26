class Vehicle < Crawler
  def build
    sql = 'SELECT * FROM vehicle'
    sqlArrival = 'INSERT INTO timetable (id, station_id, vehicle_id, departure_time, vehicle_type, vehicle_name, vehicle_notes) VALUES (?, ?, ?, ?, ?, ?, ?)'
    sqlVehicleData = 'UPDATE vehicle SET vehicle_type = ?, vehicle_name = ?, time_start = ?, time_end = ?, station_start = ?, station_end = ? WHERE vehicle_id = ?'
    
    p 'START ' + Time.new.strftime('%Y-%m-%d %H:%M:%S')
    
    rows = @db.execute(sql)
    vehicleData = []
    rows.each_with_index do |vehicle, k|
      vehicleNameNorm, stationB, arrivalTime = vehicle['vehicle_id'].split('_')
      sql = 'SELECT * FROM timetable WHERE vehicle_id = ? ORDER BY departure_time LIMIT 1'
      stopA = @db.execute(sql, vehicle['vehicle_id'])
      
      vehicleRow = {
          'vehicle_id'    => vehicle['vehicle_id'],
          'vehicle_type'  => stopA[0]['vehicle_type'],
          'vehicle_name'  => stopA[0]['vehicle_name'],
          'time_start'    => stopA[0]['departure_time'],
          'time_end'      => arrivalTime[0,2] + ':' + arrivalTime[2,2],
          'station_start' => stopA[0]['station_id'].to_i,
          'station_end'   => stationB.to_i
      }
      
      vehicleData.push(vehicleRow)
      if (vehicleData.length > 5000 || rows.length == (k + 1))
        @db.transaction
          vehicleData.each do |vehicleRow|
            @db.execute(sqlArrival, nil, vehicleRow['station_end'], vehicleRow['vehicle_id'], vehicleRow['time_end'], vehicleRow['vehicle_type'], vehicleRow['vehicle_name'], 'vehicle_arrival')
            @db.execute(sqlVehicleData, $MAP_VEHICLETYPE_STATIONTYPE[vehicleRow['vehicle_type']], vehicleRow['vehicle_name'], vehicleRow['time_start'], vehicleRow['time_end'], vehicleRow['station_start'], vehicleRow['station_end'], vehicleRow['vehicle_id'])
          end
        @db.commit
        vehicleData = []
      end
    end
    
    p 'END ' + Time.new.strftime('%Y-%m-%d %H:%M:%S')
  end #end build
end