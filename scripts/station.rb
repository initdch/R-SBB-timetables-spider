require "./inc/point_polygon.rb"

class Station < Crawler
  def fetch
    sql = "SELECT * FROM station"
    checkedIDs = []
    
    begin
      p "START ITERATION"
      
      stopSearching = true

      rows = @db.execute(sql)
      knownIDs = self.getKnownIDs(rows)

      rows.each do |station|
        sbbID = station['id']
        if checkedIDs.include?(sbbID)
          next
        end
        
        # p "Searching around " + station['name'] + "(" + sbbID + ")"
        newIDs = self.findStationsNear(sbbID)
        
        checkedIDs.push(sbbID)
        
        if (newIDs - knownIDs).length > 0 
          stopSearching = false
        end
      end
    end until stopSearching
  end
  
  def clean_geo
    sql = "SELECT id, x, y FROM station"
    rows = @db.execute(sql)
    
    contourCSV = Dir.pwd + "/resources/contour_ch_wgs84.txt"
    chPolygon = Polygon.new
    chPolygon.load_from_file(contourCSV)

    rows.each do |r|
      if ! chPolygon.contains_point?({'x' => r['x'].to_f, 'y' => r['y'].to_f})
        sql = "DELETE FROM station WHERE id = " + r['id']
        @db.execute(sql)
      end
    end
  end
  
  # # Why doesn't work ?
  # private
  
  def getKnownIDs rows
    ids = []
    rows.each do |row|
      ids.push(row['id'])
    end
    return ids
  end
  
  def findStationsNear id
    # TODO: stationCacheFolder - global scope ?
    stationCacheFolder = Dir.pwd + "/tmp/cache/station"
    stationCacheFile = stationCacheFolder + "/" + id + ".html"
    
    if ! File.file? stationCacheFile 
      sbbURL = "http://fahrplan.sbb.ch/bin/bhftafel.exe/dn?distance=50&input=" + id + "&near=Anzeigen"
      p "Fetching " + sbbURL
      sbbHTML = open(sbbURL)

      sleep 0.1
      
      File.copy(sbbHTML.path, stationCacheFile)
    end
    
    stationHTML = IO.read(stationCacheFile)
    doc = Nokogiri::HTML(stationHTML)
    
    newIDs = []
    
    doc.xpath('//tr[@class="zebra-row-0" or @class="zebra-row-1"]/td[1]/a[2]').each do |link|
      coordinates = link.parent().children()[0]['href'].scan(/Location0\.X=([0-9]+?)&REQMapRoute0\.Location0\.Y=([0-9]+?)&/)
      longitude = coordinates[0][0].to_i * 0.000001
      latitude = coordinates[0][1].to_i * 0.000001
      
      if pointIsOutside(longitude, latitude)
        next
      end

      sbbID = link['href'].scan(/input=([0-9]+?)&/).to_s
      newIDs.push(sbbID)

      sql = "SELECT count(*) from station WHERE id = ?"
      alreadyIn = 1 === @db.get_first_value(sql, sbbID).to_i
      if ! alreadyIn
        # p "Inserting in DB " + link.content + "(" + sbbID + ")"
        sql = "INSERT INTO station (id, name, x, y) VALUES (?, ?, ?, ?)"
        
        # TODO: better way -- now is too slow ?
        begin
          @db.execute(sql, sbbID, link.content, longitude, latitude)
        rescue => e
          if e.message != 'database is locked'
            raise e.message
          end
          sleep 1
        end
      end
    end
    
    return newIDs
  end
  
  def pointIsOutside longitude, latitude
    cornerSW_X = 5.85
    cornerSW_Y = 45.75
    cornerNE_X = 10.7
    cornerNE_Y = 47.8
    
    return (longitude < cornerSW_X) || (latitude > cornerNE_Y) || (longitude > cornerNE_X) || (latitude < cornerSW_Y)
  end
end