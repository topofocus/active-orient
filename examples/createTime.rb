if $0 == __FILE__
  puts "the time-graph example is completely rewritten"
  puts "changing into the directory and starting the demo in 10 sec."
  sleep 10
  print %x{ cd #{File.expand_path(File.dirname(__FILE__))}/time_graph ; ruby  createTime.rb }
  
  Kernel.exit
end
#require 'time'
require '../config/boot'

## historic stuff 

def create1month

	database_classes = [:hour, :day, :month, :time_base,  :time_of ]
	puts "allocated-database-classes: #{ORD.database_classes.join(" , ")} "
	puts database_classes.map{|c| ORD.database_classes.include?( c.to_s ) ? c : nil }.compact.size 
	if database_classes.map{|c|  ORD.database_classes.include?( c.to_s ) ? c : nil }.compact.size <= 5
	print " deleting database tables \n"
	database_classes.each{ | c | d_class=  c.to_s.classify.constantize  # works if namespace=Object
				     d_class.delete_class if d_class.present? }
	else
	  puts " omitting deletion of database-classes "
	end
	ORD.create_vertex_class :time_base
	ORD.create_classes( :hour, :day, :month ){ :time_base } # create three vertex classes
	TimeBase.create_property :value_string, type: :string  
	TimeBase.create_property :value, type: :string  
	ORD.create_edge_class :time_of 
	ORD.create_edge_class :day_of 


#  hour_class   = r.create_vertex_class "Hour", properties: {value_string: {type: :string}, value: {type: :integer}}
#  hour_class.alter_property property: "value", attribute: "MIN", alteration: 0
#  hour_class.alter_property property: "value", attribute: "MAX", alteration: 23
#
#  day_class    = r.create_vertex_class "Day", properties: {value_string: {type: :string}, value: {type: :integer}}
#  day_class.alter_property property: "value", attribute: "MIN", alteration: 1
#  day_class.alter_property property: "value", attribute: "MAX", alteration: 31
#
#  month_class  = r.create_vertex_class "Month", properties: {value_string: {type: :string}, value: {type: :integer}}
#  month_class.alter_property property: "value", attribute: "MIN", alteration: 1
#  month_class.alter_property property: "value", attribute: "MAX", alteration: 12
#

#  timeof_class = r.create_edge_class "TIMEOF"

  timestamp = DateTime.new 2016,2,29 # or strptime "1456704000",'%s' 
  month_vertex =Month.create value_string: "March", value: 3
  for day in 1..31
    day_vertex = Day.create value_string: "March #{timestamp.day}", value: day
    for hour in 0..23
      print "#{timestamp.year} #{timestamp.month} #{timestamp.day} #{timestamp.hour} \n"
      hour_vertex = Hour.create value_string: "March #{timestamp.day} #{timestamp.hour}:00", value: hour
      TimeOf.create_edge from: day_vertex, to: hour_vertex
      timestamp += Rational(1,24)  # + 1 hour
    end
    DayOf.create_edge from: month_vertex, to: day_vertex
  end
end


create1month

print "1 #{Month.all} \n \n"

firstmonth = Month.first
print "2 #{firstmonth.to_human} \n \n"
print "2.5 #{firstmonth.value} \n \n"

puts firstmonth.inspect
days = firstmonth.out_day_of
print "3 #{days.to_human} \n \n"

first_day = firstmonth.out_day_of[0].in
print "4 #{first_day.to_human} \n \n"

puts Month.first.out_day_of[0].in.out_time_of[12].inspect
thirteen_hour = firstmonth.out_day_of[0].in.out_time_of[12].in
print "5 #{thirteen_hour.value} \n \n"
print "6 #{thirteen_hour.to_human} \n \n"

test2 = firstmonth["out_day_of"].map{|x| x["in"]}
print "7 #{test2} \n \n"

mon.add_edge_link name: "days", direction: "out", edge: "time_of"
print "8 #{firstmonth.days.map{|x| x.value}} \n \n"

print "9 #{firstmonth.days.value_string} \n \n"

