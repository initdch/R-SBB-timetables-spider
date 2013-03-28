class Timetable < Crawler
  def parse
    p "START " + Time.new.strftime("%Y-%m-%d %H:%M:%S")
    
    sql = "SELECT * FROM station"
    rows = @db.execute(sql)

		# Set the PRAGMA Synchronous to normal to enable faster insert
		# System crash or power failure may corrupt the database
		@db.synchronous=1

    stationCacheFolder = Dir.pwd + "/tmp/cache/departure"
    
    kInserts = 1
    
    @db.transaction
      rows.each do |r|
        page = 1
        sbbID = r['id']
      
        while true
          cacheFile = stationCacheFolder + "/" + sbbID.to_s + "_" + page.to_s + ".html"
          if ! File.exists? cacheFile
            break
          end
      
          doc = Nokogiri::HTML(IO.read(cacheFile))
          row = doc.xpath('//table[@class="hfs_stboard"]//tr[contains(@class,"zebra-row-2") or contains(@class,"zebra-row-3")][td[not(@colspan)]]')
      
          row.each do |tr|				       
            begin
              depTime         = tr.xpath('td[@class="time"]/span').text()
              vehicleType     = tr.xpath('td[@class="journey"]/a/img')[0]['src'].scan(/products\/(.*)_pic\.png$/)[0][0]
              vehicleName     = tr.xpath('td[@class="journey"]/a').text().gsub(/\n/, '')
              stationID       = tr.xpath('td[@class="result"]/a[1]')[0]['href'].scan(/input=([0-9]+?)&/)[0][0]
              vehicleNotes    = tr.xpath('td[@class="result"]/span[@class="rs"]').text().gsub(/\n/, '')

              # Build vehicle ID 
              stationEndID    = tr.xpath('td[@class="result"]/span[@class="bold"]/a')[0]['href'].scan(/input=([0-9]+?)&/)[0][0]
              stationEndTime  = tr.xpath('td[@class="result"]').text().scan(/[0-9:]{5}/).last().sub(':', '')
              vehicleID = vehicleName.gsub(/\s/, '') + '_' + stationEndID + '_' + stationEndTime
            rescue => e
              p "ERROR: wrong XPATH while parsing " + cacheFile
              p e.message
              next
            end
            
            sql = "INSERT INTO timetable (id, station_id, vehicle_id, departure_time, vehicle_type, vehicle_name, vehicle_notes) VALUES (?, ?, ?, ?, ?, ?, ?)"
            begin
              @db.execute(sql, nil, stationID, vehicleID, depTime, vehicleType, vehicleName, vehicleNotes)
              kInserts += 1
              
              # TODO: is there a faster way to perform man inserts ?
              if kInserts > 10000
                kInserts = 1
                @db.commit
                puts  "(" + Time.new.strftime("%Y-%m-%d %H:%M:%S") + ") Batch INSERTs"
                @db.transaction
              end
            rescue => e
              if e.message != 'database is locked'
                raise e.message
              end
              sleep 1
            end
          end
      
          page += 1
        end #End station pages
      end #End SQL
    @db.commit 
    p "END " + Time.new.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  def remove_duplicates
    p "START " + Time.new.strftime("%Y-%m-%d %H:%M:%S")
    
    ids2Delete = []
    
    sql = "SELECT id FROM station"
    rows = @db.execute(sql)
    rows.each_with_index do |station, k|
      sql = "SELECT GROUP_CONCAT(id) AS ids FROM timetable WHERE station_id = " + station['id'].to_s + " GROUP BY (departure_time || vehicle_id) HAVING COUNT(id) > 1"
      dRows = @db.execute(sql)
      if dRows.length == 0
        next
      end
      
      ids = []
      dRows.each do |dRow|
        ids += dRow['ids'].split(',')[1..-1]
      end
      ids2Delete.push(ids)
    end
    
    @db.transaction
      ids2Delete.each do |ids|
        sql = "DELETE FROM timetable WHERE id IN (" + ids.join(',') + ")"
        @db.execute(sql)
      end
    @db.commit
    
    p "END " + Time.new.strftime("%Y-%m-%d %H:%M:%S")
  end
end
