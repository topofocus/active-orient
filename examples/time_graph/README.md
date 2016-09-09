#Example: Time Graph

The bin-directory contains a customized console-application. 
Any libraries are included and one can start exploring the features immediately.

*Prerequisites* : 
* Edit the Gemfile, update the pathes to include the orientdb_jruby an d activeorient gem
* Run "Bundle install" and "Bundle update"
* customize config/connect.yml

There is a rspec-section, run "bundle exec guard", edit the spec-files and start the test by saving the dataset.

To play around, start the console by
  cd bin
  ./active-orient-console t  # test-modus

The Database is initialized/resetted by calling

```ruby
TG::Init.init_database
```
This executes the code located in 'config/init_db.rb'

After this, quit the console and start again.


The following hierarchy is build:

```ruby
- E				# ruby-class
- - month_of		  TG::MONTH_OF
- - day_of		      TG::DAY_OF
- - time_of		      TG::TIME_OF
- V
- - time_base		  TG::TimeBase
- - - jahr		      TG::Jahr
- - - monat		      TG::Monat
- - - stunde		  TG::Stunde
- - - tag		      TG::Tag
```
And this Graph is realized

```ruby
Jahr -- [Month_of] -- Monat --[DAY_OF]-- Tag --[TIME_OF]-- Stunde
```
and populated by calling 

```ruby
TG::CreateTime.populate( a year or a range )  # default: 1900 .. 2050
```
If only on year is specified, a Monat--Tag--Stunde-Grid is build, otherwise a Jahr--Monat--Tag one.
You can check the Status by counting the records of the Classes

```ruby
TG::Jahr.count			# 151
TG::Monat.count 		# 1812
TG::Tag.count 			# 55152
TG::Stunde.count		#
```
which should be equal to the counts of the Edge-Classes MONTH_OF, DAY_OF and TIME_OF

In the Model-directory, customized methods simplify the usage of the graph.

Some Examples:
Assuming, you build a standard day-based grid

```ruby

include TG					# we can omit the TK prefix

Jahr[2000]    # --> returns a single object
=> #<TG::Jahr:0x00000004ced160 @metadata={"type"=>"d", "class"=>"jahr", "version"=>13, "fieldTypes"=>"out_month_of=g", "cluster"=>34, "record"=>101}, @d=nil, @attributes={"value"=>2000, "out_month_of"=>["#53:1209", "#54:1209", "#55:1209", "#56:1209", "#53:1210", "#54:1210", "#55:1210", "#56:1210", "#53:1211", "#54:1211", "#55:1211", "#56:1211"], "created_at"=>Fri, 09 Sep 2016 10:14:30 +0200}>


Jahr[2000 .. 2005].value  # returns an array
 => [2003, 2000, 2004, 2001, 2005, 2002] 

Jahr[2000 .. 2005].monat(5..7).value  # returns the result of the month-attribute (or method)
 => [[5, 6, 7], [5, 6, 7], [5, 6, 7], [5, 6, 7], [5, 6, 7], [5, 6, 7]] 

Jahr[2000].monat(4, 7).tag(4, 15,24 ).datum  # adresses methods or attributes of the specified day's
 => [["4.4.2000", "15.4.2000", "24.4.2000"], ["4.7.2000", "15.7.2000", "24.7.2000"]] 
 ## unfortunatly »Jahr[2000 .. 2015].monat( 3,5 ).tag( 4 ..6 ).datum « does not fits now
 ## instead »Jahr[2000..2015].map{|y| y.monat( 3,5 ).tag( 4 ..6 ).datum } « does the job.
```

To filter datasets in that way, anything repersented is fetched from the database and works
for small and large Grid's

You can do neat ruby-array playings, too, which are limited to the usual sizes

```ruby

Tag[31][2..4].datum  # display three months with 31 days 
 => ["31.10.1901", "31.1.1902", "31.5.1902"]

```
First, fetch all Tag-Objects with the Value 31. This is done by an ordinary  query, as defined in the 
timebase model file. The result is an array of Tag-Objects. Then the  count of month since the first 
Grid-Month can be queried by a second []-argument

Not surprisingly, the first occurence of the day is not the earliest date in the grid. Its just the first one,
fetched from the database.

``` ruby
Tag[1][1].datum
=> "1.5.1900"    # Tag[1][0] correctly fetches "1.1.1900"
Tag[1].last.datum
 => "1.11.2050"
 ## however, 
Jahr[2050].monat(12).tag(1)  # exists:
=> [["1.12.2050"]]
```



lets create a simple diary

```ruby
include TG
CreateTime.populate 2016
ORD.create_vertex_class :termin
 => Termin
ORD.create_edge_class   :date_of
 => DATE_OF
DATE_OF.create from: Monat[8].tag(9).stunde(12), 
	       to: Termin.create( short: 'Mittagessen', 
				  long: 'Schweinshaxen essen mit Lieschen Müller', 
				  location: 'Hofbauhaus, München' )
 => #<DATE_OF:0x0000000334e038 (..) @attributes={"out"=>"#21:57", "in"=>"#41:0", (..)}> 
# create some regular events
# attach breakfirst at 9 o clock from the 10th to the 21st Day in the current month
DATE_OF.create from: Monat[8].tag(10 .. 21).stunde( 9 ), to: Termin.create( :short => 'Frühstück' )
 => #<DATE_OF:0x000000028d5688 @metadata={(..) "cluster"=>45, "record"=>8}, 
			      @attributes={"out"=>"#22:188", "in"=>"#42:0",(..)}>

t = Termin.where short: 'Frühstück'
t.in_date_of.out.first.datum
  => ["10.8.2016 9:00", "11.8.2016 9:00", "12.8.2016 9:00", "13.8.2016 9:00", "14.8.2016 9:00", "15.8.2016 9:00", "16.8.2016 9:00", "17.8.2016 9:00", "18.8.2016 9:00", "19.8.2016 9:00", "20.8.2016 9:00", "21.8.2016 9:00"]


```


Another approach, starting with the simple graph 



```ruby
Monat[month].tag.each{|d| d.stunde.each{|s| s.termin=[]; s.save } } # populate hour-vertices 
# we append our dates to the termin-property
Monat[month].tag[9].stunde[8].termin << "Post"
Monat[month].tag[9].stunde[9].termin << "zweites Frühstück"
Monat[month].tag.each{|t| t.stunde[12].termin << "Mittag"}
```







