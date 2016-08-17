#require 'time'



class CreateTime
  class << self   # singleton class
    def populate_month year = Date.today.year, month = Date.today.month
      timestamp = DateTime.new year, month,1
      if Monat.where( :value => month ).blank?
	der_monat= Monat.create value_string: timestamp.strftime("%B"), value: timestamp.month
	last_month_day =  (DateTime.new( year, month+1, 1)-1).day rescue 31  # rescue covers month > 12
	(0 .. last_month_day ).each do | tag |
	  der_tag = Tag.create value_string: "March #{timestamp.day}", value: tag 
	  print der_tag.value+" > "
	  ( 0 .. 23 ).each do | stunde |
	    die_stunde = Stunde.create value_string: "March #{timestamp.day} #{timestamp.hour}:00", value: stunde
	    print die_stunde.value + " .. "
	    TIME_OF.create from: der_tag, to: die_stunde
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
  CrateTime.populate_month

  

  puts "Features of the DateTime Graph"
  puts '-' * 40
  puts
  puts "Allocated Month => Month.first.value :" +ThisMonth.first.value.to_s
  puts
  puts "Adressing Days => Month.first.day(2).value:" + ThisMonth.first.day(2).value.to_s
  puts
  puts "Adressing Hours => Month.first.day(2).hour(4).value :" + ThisMonth.first.this_day(2).this_hour(4).value.to_s




end
