class Departure < Crawler
  def initialize
    super

    time = Time.new
    @dateStart = time.strftime("%d.%m.%y")
    @dateEnd = "10.12.11"
  end

  def fetch
    # TODO: stationCacheFolder - global scope ?
    stationCacheFolder = Dir.pwd + "/tmp/cache/departure"
    
    sql = "SELECT * FROM station"
    rows = @db.execute(sql)
    k = 1
    
    maxPages = 500
    
    rows.each do |station|
      sbbID = station['id'];
      page = 1
      time = "00:00"
      
      # p "Departures for " + sbbID + " " + k.to_s + "/" + rows.length.to_s
      
      begin
        cacheFile = stationCacheFolder + "/" + sbbID.to_s + "_" + page.to_s + ".html"
        
        if ! File.file? cacheFile 
          # TODO - 'dn' to be replaced later with 'en'
          sbbURL = "http://fahrplan.sbb.ch/bin/bhftafel.exe/dn?maxJourneys=50&start=Anzeigen&boardType=dep"
          sbbURL += "&input=" + sbbID.to_s
          sbbURL += "&dateBegin=" + @dateStart
          sbbURL += "&dateEnd=" + @dateEnd
          sbbURL += "&time=" + time

          p "Fetching " + sbbURL
          begin
            sbbHTML = open(sbbURL)
            sleep 0.1
            FileUtils.cp(sbbHTML.path, cacheFile)
          rescue
            p "ERROR: FETCHING " + sbbURL
            break
          end
        end
        
        doc = Nokogiri::HTML(IO.read(cacheFile))
        
        hasNextPage = doc.xpath('//table[@class="hafas-content"]//td[span[@class="red"]]//a[contains(text(),"Weitere")]').length == 1
        if hasNextPage
          begin
            timeLast = doc.xpath('//table[@class="hafas-content hafas-sq-content"]//tr[contains(@class,"zebra-row-3") or contains(@class,"zebra-row-2")][td[not(@colspan)]][last()]/td[1]/span')[0].text()
          rescue
            p "ERROR: XPATH IN " + cacheFile
            timeLast = time
          end
          
          if timeLast < time
            lastPage = true
          else
            lastPage = false
            page = page + 1
            time = timeLast
          end
        else
          lastPage = true
        end
        
        if page > maxPages
          p "ERROR - maximum pages reached for " + sbbID.to_s
          break
        end

      end until lastPage
      
      k = k + 1
    end
  end  
end