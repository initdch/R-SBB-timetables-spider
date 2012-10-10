require 'digest/sha1'
require 'cgi'

require "./inc/point_polygon.rb"

class Station < Crawler
  def initialize
    super
    
    sql = "SELECT * FROM settings WHERE key = 'bounds'"
    @bounds = @db.execute(sql)[0]['value'].split(',')
  end
  
  def fetch
    sql = "SELECT * FROM station"
    checkedIDs = []
    
    begin
      stopSearching = true

      rows = @db.execute(sql)
      dbIDs = self.extractIDs(rows)
      
      p 'START ITERATION: ' + rows.length.to_s + ' records in DB / ' + checkedIDs.length.to_s + ' visited'
      
      rows.each do |station|
        sbbID = station['id']

        if checkedIDs.include?(sbbID)
          # Exclude the station in case of a further iteration
          next
        end
        
        # p "Searching around " + station['name'] + "(" + sbbID + ")"
        newStations = self.findStationsNear(sbbID)
        newStations.each do |station|
          if dbIDs.include?(station['id'])
            next
          end
          self.insertStation(station)
        end

        checkedIDs.push(sbbID)
        
        newIDs = self.extractIDs(newStations)
        if (newIDs - dbIDs).length > 0 
          # New stations found, mark another iteration
          stopSearching = false
        end
        
        dbIDs += newIDs
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
  
  def parse_type
    # See lookup_vehicle_types.rb

    p "START " + Time.new.strftime("%Y-%m-%d %H:%M:%S")
    
    stationTypes = {}
    poolNewTypes = []
    
    # First, reset the current types
    sql = 'UPDATE station SET type = ""'
    rows = @db.execute(sql)
    
    sql = "SELECT * FROM station"
    rows = @db.execute(sql)
    rows.each do |station|
      sbbID = station['id']
      sql = "SELECT GROUP_CONCAT(vehicle_type) AS types FROM timetable WHERE station_id = " + sbbID.to_s
      vehicleTypes = @db.execute(sql)[0]['types']
      if vehicleTypes == nil
        next
      end
      
      vehicleTypes = vehicleTypes.split(',').uniq
      
      finalType = nil
      vehicleTypes.each do |foundType|
        if $MAP_VEHICLETYPE_STATIONTYPE[foundType] == nil
          poolNewTypes.push(foundType)
          next
        end
          
        if finalType == nil
          finalType = $MAP_VEHICLETYPE_STATIONTYPE[foundType]
        end
        
        currentType = $MAP_VEHICLETYPE_STATIONTYPE[foundType]
        if $MAP_STATIONTYPE_PRIORITY[currentType] < $MAP_STATIONTYPE_PRIORITY[finalType]
          finalType = currentType
        end
      end
      
      if finalType != nil
        stationTypes[sbbID] = finalType
      end
    end
    
    if poolNewTypes.length > 0
      p "Please check new types: "
      poolNewTypes.uniq.sort.each do |type|
        p "'" + type + "' => '',"
      end
    else
      kSQL = 1
      sql = "UPDATE station SET type = NULL"
      @db.transaction
        stationTypes.each do |id, type|
          sql = "UPDATE station SET type = ? WHERE id = ?"
          @db.execute(sql, type, id)
          kSQL += 1
          
          if kSQL > 10000
            kSQL = 1
            @db.commit
            p "Batch SQL"
            @db.transaction
          end
        end
      @db.commit
    end
    
    p "END " + Time.new.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  def findStationsInArea bounds
    sbbMapURL = "http://fahrplan.sbb.ch/bin/query.exe/dn?mapDisplay=look&lookstops=yes&mapPixelWidth=450&mapPixelHeight=450&mapActiveZoomLevel=6&look_stopclass=1023&look_json=yes&performLocating=2";
    boundsParts = bounds.split(',')
    sbbMapURL += '&look_minx=' + (boundsParts[0].to_f * 1000000).to_i.to_s
    sbbMapURL += '&look_maxx=' + (boundsParts[2].to_f * 1000000).to_i.to_s
    sbbMapURL += '&look_miny=' + (boundsParts[1].to_f * 1000000).to_i.to_s
    sbbMapURL += '&look_maxy=' + (boundsParts[3].to_f * 1000000).to_i.to_s
    
    FileUtils.cp(open(sbbMapURL).path, Dir.pwd + '/tmp/bounds.json')
    boundsJSON = IO.read(Dir.pwd + '/tmp/bounds.json')
    # Quick and dirty, I know
    foundFirstName = boundsJSON.match(/"name" : "([^"]+?)",/)
    
    if foundFirstName == nil
      abort "No SBB station was found in the given bounds"
    end
    
    coder = HTMLEntities.new
    stationName = coder.decode(foundFirstName[1])
    newStations = findStationsNear(stationName, {'ignoreAmbigous' => false})
    
    if newStations.length == 0
      abort "No SBB station was found in the given bounds"
    end
    
    return newStations[0]
  end
  
  def insertStation station
    sql = "INSERT INTO station (id, name, x, y) VALUES (?, ?, ?, ?)"
    @db.execute(sql, station['id'], station['name'], station['x'], station['y'])
  end
  
  # # Why doesn't work ?
  # private
  
  def extractIDs rows
    ids = []
    rows.each do |row|
      ids.push(row['id'])
    end
    return ids
  end
  
  def findStationsNear input, params = {}
    defParams = {
      'ignoreAmbigous' => true
    }
    params = defParams.merge(params)
    
    input = input.to_s
    if input.match(/^[0-9]+?$/) == nil
      cacheFile = Digest::SHA1.hexdigest(input) + '.html'
    else
      cacheFile = input + '.html'
    end
    
    # TODO: stationCacheFolder - global scope ?
    stationCacheFolder = Dir.pwd + "/tmp/cache/station"
    stationCacheFile = stationCacheFolder + "/" + cacheFile
    
    def fetchSBBStation input, cacheFile, params
      sbbURL = "http://fahrplan.sbb.ch/bin/bhftafel.exe/dn?distance=50&input=" + CGI::escape(input) + "&near=Anzeigen"
      # p "Fetching " + sbbURL
      sbbHTML = open(sbbURL)
      sleep 0.1
      
      if params['ignoreAmbigous'] == false
        sbbHTML = IO.read(sbbHTML.path)
        isAmbigous = sbbHTML.match(/<option value=".+?#([0-9]+?)">/)
        if isAmbigous != nil
          params['ignoreAmbigous'] = true
          fetchSBBStation(isAmbigous[1], cacheFile, params)
        end
        
        return nil
      end
      
      FileUtils.cp(sbbHTML.path, cacheFile)
    end
    
    if ! File.file? stationCacheFile
      fetchSBBStation(input, stationCacheFile, params)
    end
    
    stationHTML = IO.read(stationCacheFile)
    doc = Nokogiri::HTML(stationHTML)
    
    newStations = []
    coder = HTMLEntities.new
    
    doc.xpath('//tr[@class="zebra-row-0" or @class="zebra-row-1"]').each do |tr|
      coordinates = tr.xpath('td[1]/a')[0]['href'].scan(/MapLocation\.X=([0-9]+?)&MapLocation\.Y=([0-9]+?)&/)
      # TODO How to avoid 45.3483299999999 ? Round, 6 decimals ?
      longitude = coordinates[0][0].to_i * 0.000001
      latitude = coordinates[0][1].to_i * 0.000001
      
      if pointIsOutside(longitude, latitude)
        next
      end

      sbbID = tr.xpath('td[2]/a')[0]['href'].scan(/input=([0-9]+?)&/)[0][0]
      newStation = {
        'id'    => sbbID.to_i,
        'name'  => coder.decode(tr.xpath('td[2]/a')[0].content),
        'x'     => longitude.round(6),
        'y'     => latitude.round(6)
      }
      
      newStations.push(newStation)
    end
    
    return newStations
  end
  
  def pointIsOutside longitude, latitude
    cornerSW_X = @bounds[0].to_f
    cornerSW_Y = @bounds[1].to_f
    cornerNE_X = @bounds[2].to_f
    cornerNE_Y = @bounds[3].to_f
    
    return (longitude < cornerSW_X) || (latitude > cornerNE_Y) || (longitude > cornerNE_X) || (latitude < cornerSW_Y)
  end
end