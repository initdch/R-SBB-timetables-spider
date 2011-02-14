class Timetable < Crawler
  def parse
    sql = "SELECT * FROM station"
    rows = @db.execute(sql)
    
    stationCacheFolder = Dir.pwd + "/tmp/cache/departure"
    
    rows.each do |r|
      page = 1
      sbbID = r['id']
      
      while true
        cacheFile = stationCacheFolder + "/" + sbbID.to_s + "_" + page.to_s + ".html"
        if ! File.exists? cacheFile
          break
        end
        
        doc = Nokogiri::HTML(IO.read(cacheFile))
        row = doc.xpath('//table[@class="hafas-content hafas-sq-content"]//tr[contains(@class,"zebra-row-2") or contains(@class,"zebra-row-3")][td[not(@colspan)]]')
        
        row.each do |tr|
          # TODO: better way ?
          if tr.css('td').length() < 5
            next
          end
          
          begin 
            td = './/td[not(span[@class="prognosis"])]'
            depTime         = tr.xpath(td + '[1]/span').text()
            vehicleType     = tr.xpath(td + '[2]/a/img')[0]['src'].scan(/products\/(.*)_pic\.gif$/)[0][0]
            vehicleName     = tr.xpath(td + '[3]/span/a').text().gsub(/\n/, '')
            stationID       = tr.xpath(td + '[4]/a[1]')[0]['href'].scan(/input=([0-9]+?)&/)[0][0]
            vehicleNotes    = tr.xpath(td + '[4]/span[@class="rs"]').text().gsub(/\n/, '')
            
            # Build vehicle ID
            stationEndID    = tr.xpath(td + '[4]/span[1]/a')[0]['href'].scan(/input=([0-9]+?)&/)[0][0]
            stationEndTime  = tr.xpath(td + '[4]').text().scan(/[0-9:]{5}/).last().sub(':', '')
            vehicleID = vehicleName.gsub(/\s/, '') + '_' + stationEndID + '_' + stationEndTime
          rescue => e
            p "ERROR: wrong XPATH while parsing " + cacheFile
            p e.message
          end
          
          sql = "INSERT INTO timetable (id, station_id, vehicle_id, departure_time, vehicle_type, vehicle_name, vehicle_notes) VALUES (?, ?, ?, ?, ?, ?, ?)"
          begin
            @db.execute(sql, nil, stationID, vehicleID, depTime, vehicleType, vehicleName, vehicleNotes)
          rescue => e
            if e.message != 'database is locked'
              raise e.message
            end
            sleep 1
          end
        end

        page += 1
      end
    end
  end
end