class Vehicle < Crawler
  def build
    sql = 'SELECT * FROM vehicle'
    sqlArrival = 'INSERT INTO timetable (id, station_id, vehicle_id, departure_time, vehicle_type, vehicle_name, vehicle_notes) VALUES (?, ?, ?, ?, ?, ?, ?)'
    sqlVehicleData = 'UPDATE vehicle SET vehicle_type = ?, vehicle_name = ?, time_start = ?, time_end = ?, station_start = ?, station_end = ? WHERE vehicle_id = ?'
		sqlStartStation = 'SELECT *  FROM timetable WHERE vehicle_id = ? ORDER BY time(departure_time, ?) LIMIT 1'
    
    p 'START ' + Time.new.strftime('%Y-%m-%d %H:%M:%S')
    
    rows = @db.execute(sql)
    vehicleData = []
    rows.each_with_index do |vehicle, k|
      vehicleNameNorm, stationB, arrivalTime = vehicle['vehicle_id'].split('_')
			endTime = arrivalTime[0,2] + ':' + arrivalTime[2,2]
			diffTime = '-' + endTime + ':01'
      stopA = @db.execute(sqlStartStation, vehicle['vehicle_id'],diffTime)
      
      vehicleRow = {
          'vehicle_id'    => vehicle['vehicle_id'],
          'vehicle_type'  => stopA[0]['vehicle_type'],
          'vehicle_name'  => stopA[0]['vehicle_name'],
          'time_start'    => stopA[0]['departure_time'],
          'time_end'      => endTime,
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
  
  def check_duplicate_stations
    def getDuplicatedStops vehicle_id, stops
      def getDifference tA, tB
        tA_Minutes = tA[0,2].to_i * 60 + tA[3,2].to_i
        tB_Minutes = tB[0,2].to_i * 60 + tB[3,2].to_i
        return tB_Minutes - tA_Minutes
      end
      
      ids2Delete = []
      stops.each_with_index do |stop, k|
        if k == 0
          next
        end
        sA = stops[k-1]['station_id']
        sB = stop['station_id']
        if sA === sB
          difference = getDifference(stops[k-1]['dep'], stops[k]['dep'])
          if difference <= 5
            ids2Delete.push(stops[k-1]['id'])
          else
            p vehicle_id.to_s + ': too big difference(' + difference.to_s + ') between ' + sA.to_s + ' and ' + sB.to_s
          end
        end
      end #each_with_index
      return ids2Delete
    end
    
    sql = 'SELECT vehicle_id FROM vehicle WHERE vehicle_type = "train"'
    # sql = 'SELECT vehicle_id FROM vehicle WHERE vehicle_id = "IRE3351_8029103_0953"'
    sqlStations = 'SELECT timetable.id, station_id, departure_time AS dep FROM timetable WHERE vehicle_id = ? ORDER BY departure_time'
    rows = @db.execute(sql)
    rows.each_with_index do |vehicle|
      stops = @db.execute(sqlStations, vehicle['vehicle_id'])
      duplicatedIDs = getDuplicatedStops(vehicle['vehicle_id'], stops)
      if duplicatedIDs.length > 0
        sqlDelete = 'DELETE FROM timetable WHERE id IN (' + duplicatedIDs.join(', ').to_s + ')'
        @db.execute(sqlDelete)
        p vehicle['vehicle_id'].to_s + ': removing ' + duplicatedIDs.join(', ')
      end
    end
  end
end
