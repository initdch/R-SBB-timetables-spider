require "rubygems"
require "nokogiri"
require "open-uri"
require "ftools"
require "sqlite3"

class StationPool
  def initialize
    @url = "http://fahrplan.sbb.ch/bin/bhftafel.exe/dn?distance=50&input=[sbbID]&near=Anzeigen"
    # TODO: db path - global scope ?
    @db = SQLite3::Database.open(Dir.pwd + "/tmp/sbb.db")
    @db.results_as_hash = true
  end

  def fetch
    sql = "SELECT * FROM station"
    result = @db.execute(sql)
    
    result.each do |station|
      p "Searching around " + station['name'] + "(" + station['id'] + ")"
      self.findStationsNear(station['id'])
    end
  end
  
  def findStationsNear id
    # TODO: stationCacheFolder - global scope ?
    stationCacheFolder = Dir.pwd + "/tmp/cache/station"
    stationCacheFile = stationCacheFolder + "/" + id + ".html"
    
    if ! File.file? stationCacheFile 
      sbbURL = @url.sub("[sbbID]", id)
      p "Fetching " + sbbURL
      sbbHTML = open(sbbURL)
      
      File.copy(sbbHTML.path, stationCacheFile)
    end
    
    stationHTML = IO.read(stationCacheFile)
    doc = Nokogiri::HTML(stationHTML)
    
    doc.xpath('//tr[@class="zebra-row-0" or @class="zebra-row-1"]/td[1]/a[2]').each do |link|
      sbbID = link['href'].scan(/input=([0-9]+?)&/).to_s

      sql = "SELECT count(*) from station WHERE id = ?"
      alreadyIn = 1 === @db.get_first_value(sql, sbbID).to_i
      if alreadyIn
        p "Entry " + link.content + "(" + sbbID + ") is already in DB. TODO: Update ?"
      else
        p "Inserting in DB " + link.content + "(" + sbbID + ")"
        sql = "INSERT INTO station (id, name) VALUES (?, ?)"
        @db.execute(sql, sbbID, link.content)
      end
    end
  end
  
  def close
    @db.close
  end
end

# Used when running 'ruby station.rb'
# s = StationPool.new
# s.fetch