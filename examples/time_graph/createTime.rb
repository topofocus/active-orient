#require 'time'



class CreateTime
  class << self   # singleton class
    def populate_month year = Date.today.year, month = Date.today.month
      timestamp = DateTime.new year, month,1
      if Monat.where( :value => month ).blank?
	der_monat= Monat.create value_string: timestamp.strftime("%B"), value: timestamp.month.to_i
	last_month_day =  (DateTime.new( year, month+1, 1)-1).day rescue 31  # rescue covers month > 12
	(0 .. last_month_day ).each do | tag |
	  der_tag = Tag.create value_string: "March #{timestamp.day}", value: tag 
	  print der_tag.value.to_s + " > "
	  ( 0 .. 23 ).each do | stunde |
	    die_stunde = Stunde.create value_string: "March #{timestamp.day} #{timestamp.hour}:00", value: stunde
	    print die_stunde.value.to_s + " .. "
	    TIME_OF.create_edge from: der_tag, to: die_stunde
	    timestamp += Rational(1,24)  # + 1 hour
	  end
	  print "\n"
	  DAY_OF.create_edge from: der_monat, to: der_tag
	end
      else
	"Month #{timestamp.strftime("%B %Y ") } exists "
      end
    end
  end
end # class

  ## here we start if the file is called from the command-lind
if $0 == __FILE__
  require './config/boot'
  ActiveOrient::OrientSetup.init_database   # --> config/init_db
  CreateTime.populate_month

  

  puts "Features of the DateTime Graph"
  puts '-' * 40
  puts
  puts "Allocated Month => Monat.first.value :" + Monat.first.value.to_s
  puts
  puts "Adressing Days => Monat.first.tag[2].value:" + Monat.first.tag[2].value.to_s
  puts
  puts "Adressing Hours => Monat.first.tag[2].stunde[4].value :" + Monat.first.tag[5].stunde[4].value.to_s




end
