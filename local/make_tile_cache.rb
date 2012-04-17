
RAILS_ENV='production'
require '/rails/ebi/config/environment'

require 'rvg/rvg'
include Magick

zoom_min = ARGV[0].to_i
zoom_max = ARGV[1].to_i
zoom_min == 0 ? zoom_min = 2 : zoom_min = zoom_min.to_i
zoom_max == 0 ? zoom_max = 9 : zoom_max = zoom_max.to_i

ignore_counties = County.all(:select => :id, :conditions => "state = 'Alaska' or state = 'Hawaii'").collect(&:id)

usboundaries = []
usboundaries[0] = { :xmax => 80.0, :ymax => 110.0, :xmin => 39.0, :ymin => 87.0 }
usboundaries[1] = { :xmax => 160.8, :ymax => 220.0, :xmin => 78.6, :ymin => 175.0 }
usboundaries[2] = { :xmax => 321.56, :ymax => 439.95, :xmin => 157.2, :ymin => 349.99 }
usboundaries[3] = { :xmax => 643.129, :ymax => 879.89, :xmin => 314.407, :ymin => 699.983 }
usboundaries[4] = { :xmax => 1286.259, :ymax => 1759.7803, :xmin => 628.8137, :ymin => 1399.9653 }
usboundaries[5] = { :xmax => 2572.51794, :ymax => 3519.56059, :xmin => 1257.62733, :ymin => 2799.93061 }
usboundaries[6] = { :xmax => 5145.03589, :ymax => 7039.121188, :xmin => 2515.254659, :ymin => 5599.861214 }
usboundaries[7] = { :xmax => 10290.0717796, :ymax => 14078.242376, :xmin => 5030.5093177, :ymin => 11199.7224271 }
usboundaries[8] = { :xmax => 20580.14355911, :ymax => 28156.48475205, :xmin => 10061.01863538, :ymin => 22399.4448541 }
usboundaries[9] = { :xmax => 41160.287118222, :ymax => 56312.969504094, :xmin => 20122.037270756, :ymin => 44798.889708208 }
usboundaries[10] = { :xmax => 82320.5742364445, :ymax => 112625.939008187, :xmin => 40244.0745415111, :ymin => 89597.7794164164 }
usboundaries[11] = { :xmax => 164641.148472889, :ymax => 225251.878016374, :xmin => 80488.1490830222, :ymin => 179195.558832833 }

crops = LocationYield.all(:select => "distinct(species)").collect {|x| x["species"] }

crops.each do |crop|
  p crop
  
  color_range = {}

 
  if ['miscanthus','poplar','switchgrass'].include?(crop) 
    color_range[:max] = 40.0
    color_range[:min] = 0.0
    #next
  else
    color_range[:max] = LocationYield.first(:order => 'yield desc', :conditions => ["species = ?",crop]).yield.to_f
    color_range[:min] = LocationYield.first(:order => 'yield asc', :conditions => ["species = ?",crop]).yield.to_f
  end
  p color_range.to_yaml   
  #color_range[:increment] = (color_range[:max] - color_range[:min])/120
  color_range[:increment] = (color_range[:max] - color_range[:min])/80

  #Draw Crop Scale
  RVG::dpi = 600
  scale_list1 = Magick::ImageList.new
  scale_list1 << Magick::Image.new(30, 5) { self.background_color = "none" }
  if ['miscanthus','poplar','switchgrass'].include?(crop) 
    scale_list1 << Magick::Image.new(30, 240, Magick::GradientFill.new(0,0,240,0,"hsla(120,100,90,0.5)","hsla(120,100,10,0.5)"))
  else
    scale_list1 << Magick::Image.new(30, 240, Magick::GradientFill.new(0,0,240,0,"hsla(280,100,50,0.8)","hsla(360,100,50,0.8)"))
  end
  scale_list1[1].opacity = Magick::MaxRGB/2 
  scale_list2 = Magick::ImageList.new
  scale_list2 << scale_list1.append(true)
  scale_list2 << Magick::Image.new(50, 250){ self.background_color = "none"  }
  txt = Draw.new


  if ['miscanthus','poplar','switchgrass'].include?(crop) 
    txt.annotate(scale_list2[1],0,0,5,10,"0"){
      self.font_family = 'Helvetica'
      self.pointsize = 12
      self.stroke = "#000000"
    }

    1.upto(8) do |_i|
      txt.annotate(scale_list2[1],0,0,5,_i*30+5,"#{(_i*color_range[:max]/8).round(2)}"){
        self.font_family = 'Helvetica'
        self.pointsize = 12
        self.stroke = "#000000"
      }
    end
  else
    txt.annotate(scale_list2[1],0,0,5,10,"#{color_range[:min]}"){
      self.font_family = 'Helvetica'
      self.pointsize = 12
      self.stroke = "#000000"
    }

    1.upto(8) do |_i|
      txt.annotate(scale_list2[1],0,0,5,_i*30+5,"#{(color_range[:min] + _i*((color_range[:max]-color_range[:min])/8)).round(2)}"){
        self.font_family = 'Helvetica'
        self.pointsize = 12
        self.stroke = "#000000"
      }
    end
  end
  
  scale_list3 = Magick::ImageList.new
  scale_list3 << Magick::Image.new(80, 30) { self.background_color = "none" }
  scale_list3 << scale_list2.append(false)

  Draw.new.annotate(scale_list3[0],0,0,5,13,"Annual Yield"){
        self.font_family = 'Helvetica'
        self.pointsize = 12
        self.stroke = "#000000"
      }
  Draw.new.annotate(scale_list3[0],0,0,5,26,"(Mg / ha)"){
        self.font_family = 'Helvetica'
        self.pointsize = 12
        self.stroke = "#000000"
      }


  scale_list3.append(true).write("/rails/ebi/public/#{crop}-scale.png")
  
  zoom_min.upto(zoom_max) do |zoom|
  
    t = Time.now
    countyx_max = usboundaries[zoom][:xmax]
    countyy_max = usboundaries[zoom][:ymax]
    countyx_min = usboundaries[zoom][:xmin]
    countyy_min = usboundaries[zoom][:ymin]
  
    0.upto((2**zoom)-1) do |xx|
      0.upto((2**zoom)-1) do |yy|
        
  
        tt = Time.now
  
        #Check our params, fallback to defaults if necessary
        tmpx,tmpy = xx,yy
        paramx = 256*tmpx
        paramy = 256*tmpy
  
        tile_dir = "/rails/ebi/public/maps/mapoverlay/#{crop}"
        tile_file = "/rails/ebi/public/maps/mapoverlay/#{crop}/#{tmpx}-#{tmpy}-#{zoom}.png"
  
        next if File.symlink?(tile_file)
  
        Dir.mkdir(tile_dir) if !File.directory?(tile_dir)
  
        merc = MercatorProjection.new(zoom)
          
        if paramx.to_f <= countyx_max and (paramx+256).to_f >= countyx_min and paramy.to_f <= countyy_max and (paramy+256).to_f >= countyy_min
      
          # If any point of the county is in the square include iti the county
          if zoom == 0
            counties = County.all(:select => "id", :conditions => ["id not in (?)", ignore_counties]).collect(&:id).uniq
          elsif zoom == 1 and paramx == 0 and paramy == 0
            counties = County.all(:select => "id", :conditions => ["id not in (?)", ignore_counties]).collect(&:id).uniq
          elsif zoom == 1
            counties = []
          else
            range = {}
            # Zoom 8 is the first level panels are inside a county so they do not show up. San Bernardino County is the largest, outside Alaska
            # if we just add half of the size to the max and subtract half the size to the min of San Bernardino County at the different
            # levels ( minus 256 ), we know we will catch the appropiate county (plus some others)
            # 8 : x = 668, y = 430
            # 9 : x = 1336, y = 860
            # 10 : x = 2672, y = 1720
            # 11 : x = 5344, y = 3440
    
            if zoom == 8
              range["xmin"] = paramx - 206
              range["xmax"] = paramx + 256 + 206
              range["ymin"] = paramy - 87
              range["ymax"] = paramy + 256 + 87
            elsif zoom == 9
              range["xmin"] = paramx - 540
              range["xmax"] = paramx + 256 + 540
              range["ymin"] = paramy - 302
              range["ymax"] = paramy + 256 + 302
            elsif zoom == 10
              range["xmin"] = paramx - 1208
              range["xmax"] = paramx + 256 + 1208
              range["ymin"] = paramy - 732
              range["ymax"] = paramy + 256 + 732
            elsif zoom == 11
              range["xmin"] = paramx - 2544
              range["xmax"] = paramx + 256 + 2544
              range["ymin"] = paramy - 1592
              range["ymax"] = paramy + 256 + 1592
            else
              range["xmin"] = paramx
              range["xmax"] = paramx + 256
              range["ymin"] = paramy
              range["ymax"] = paramy + 256
            end
            counties = CountyBoundary.all(:select => "distinct(county_id)", :conditions => ["zoom#{zoom}x <= ? and zoom#{zoom}x >= ? and zoom#{zoom}y <= ? and zoom#{zoom}y >= ? and county_id not in (?)",range["xmax"],range["xmin"],range["ymax"],range["ymin"],ignore_counties]).collect(&:county_id).uniq
          end
    
     
          if counties.length > 0
            rvg = RVG.new(256,256).viewbox(paramx,paramy,256,256) do |canvas|
              canvas.background_fill_opacity = 0.0
    
              countys = County.all(:conditions => ["counties.id in (?)", counties])
              countys.each do |county|
    
                next if ["Hawaii","Alaska"].include?(county.state)
                
                avg = county.location_yields.find_by_species(crop).yield.to_f rescue nil
                #p county.to_yaml if avg.nil?
                if avg.nil?
                  color = "hsl(0,100,100)"
                else
                  #tmp = ((120*avg.to_f)/color_range[:max]).round(0)
                  if ['miscanthus','poplar','switchgrass'].include?(crop) 
                    # light Colors are at bottom of scale...
                    tmp = (80-2*avg.to_f).round(0)
                    color = "hsla(120,100,#{10+tmp.to_i},0.5)"
                  else
                    tmp = 280+(80*(((0-color_range[:min].to_f)+avg.to_f)/(color_range[:max]-color_range[:min]))).round(0).to_i
                    color = "hsla(#{tmp},100,50,0.8)"
                  end
                end

                # At low enough zoom levels many of the counties are a single pixel
                # Could use RVG::Group by setting stroke_width to 1, but that might mess with
                # higher zoom levels 
                path = county.county_paths.find_by_zoom(zoom).path
                if path.split(" ").length == 1
                  canvas.g do |_canvas|
                    _canvas.circle(1,path.split(",")[0],path.split(",")[1]).styles(:fill=>"#{color}")
                  end
                else
                  canvas.g do |_canvas|
                    #_canvas.path("M #{path}Z").styles(:stroke_width => 0.0000000001, :fill_opacity => 0.5, :fill => "#{color}", :stroke_opacity => 0.0, :stroke => "#{color}")
                    _canvas.path("M #{path}Z").styles(:stroke_width => 0.0000000001, :fill => "#{color}", :stroke_opacity => 0.0, :stroke => "#{color}")
                  end
                end
              end
            end
          end
        end
    
        if !rvg.nil?
          img = rvg.draw
          img.write(tile_file)
        else
          File.delete(tile_file) if File.exists?(tile_file)
          File.symlink("/rails/ebi/public/maps/mapoverlay/blank_tile.png",tile_file)
        end
        #p "#{xx}-#{yy}-#{zoom} : #{(Time.now - tt).to_f}" if (Time.now - tt).to_f > 1
      end
    end
    puts "Zoom #{zoom} total: #{(Time.now - t).to_f}"
  end
end
  