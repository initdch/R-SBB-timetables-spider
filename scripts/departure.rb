class Departure < Crawler
  def initialize
    super

    # time = Time.new
    # @dateStart = time.strftime("%d.%m.%y")
    # @dateEnd = "1.12.#{time.strftime("%Y")}"
    
    @dateStart = 04.06.13
    @dateEnd = 04.06.13
  end

  def fetch
    # TODO: stationCacheFolder - global scope ?
    stationCacheFolder = Dir.pwd + "/tmp/cache/departure"
    
    sql = "SELECT * FROM station"
    rows = @db.execute(sql)
    k = 1
    
		# biggest station had ~650 pages (March 2013)
    maxPages = 1000
    
		puts puts  "(" + Time.new.to_s + ") Start fetching:  0/" + rows.length.to_s + "\n"
    rows.each do |station|
      sbbID = station['id'];
      page = 1
      time = "00:00"
      
			# Output progress
			if k % 500 == 0
				puts  "(" + Time.new.to_s + ") Fetched " + k.to_s + "/" + rows.length.to_s
			end
      
      begin
        cacheFile = stationCacheFolder + "/" + sbbID.to_s + "_" + page.to_s + ".html"
        
        if ! File.file? cacheFile 
          # TODO - 'dn' to be replaced later with 'en'
          sbbURL = "http://fahrplan.sbb.ch/bin/stboard.exe/dn?maxJourneys=50&start=Anzeigen&boardType=dep"
          sbbURL += "&input=" + sbbID.to_s
          sbbURL += "&dateBegin=" + @dateStart
          sbbURL += "&dateEnd=" + @dateEnd
          sbbURL += "&time=" + time

					retries = 10
					timeout = 1
          begin
            sbbHTML = open(sbbURL)
          rescue StandardError=>e
						puts "\tCaught: #{e}"
						if retries > 0
							puts "\tTrying #{retries} more times \t#{timeout}sec timeout\n"
							retries -= 1
							sleep timeout
							timeout *= 2
							retry
						end
						puts "ERROR: Fetching unsuccesful " + sbbURL
            break
					else 
            sleep 0.1
            FileUtils.cp(sbbHTML.path, cacheFile)
          end
        end
        
        doc = Nokogiri::HTML(IO.read(cacheFile))
        
        hasNextPage = doc.xpath(('//div[@class="hafas"]//div[@class="buttonHolder"]//a[contains(text(),"Weitere")]')).length == 1
        if hasNextPage
          begin
            timeLast = doc.xpath('//div[@class="hafas"]//table[@class="hfs_stboard"]//tr[contains(@class,"zebra-row-")][td[not(@colspan)]][last()]/td[1]/span')[0].text()
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
      if page > 500
				puts sbbID.to_s + " had " + page.to_s + " pages\n"
			end
      k = k + 1
    end
  end  
end
