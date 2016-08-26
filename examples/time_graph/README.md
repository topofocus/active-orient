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
ActiveOrient::OrientSetup.init_database
```

This executes the code located in 'config/init_db.rb'

The following hierarchy is build:

```ruby
- E
- - day_of
- - time_of
- V
- - time_base
- - - monat
- - - stunde
- - - tag
```
And this Graph is realized

```ruby
Monat --[DAY_OF]-- Tag --[TIME_OF]-- Stunde
```
and populated by calling 

```ruby
CreateTime.populate_month	# 1 One Month whith appropoiate Days and Hours
```

You can check the Status by counting the recods of the Classes

```ruby
Monat.count 		# 1
Tag.count 			# 32
Stunde.count		# 768
```
which should be equal to the counts of the Edge-Classes DAY_OF and TIME_OF

In the Model-directory, customized methods simplify the usage of the graph.

Some Examples:

```ruby
m =  Date.today.month  # current month

Monat[m].tag.value
=> [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31] 

Monat[m].tag[9].stunde[9].value
=> 9

Monat[month].tag[9].next.datum
 => "10.8.2016" 

Stunde[9]					# [] is defined in model/timebase.rb
=> An Array with Stunde-records 
Stunde[9].datum				# datum is defined in model/stunde.rb
 => ["0.8.2016 9:00", "1.8.2016 9:00", "2.8.2016 9:00", "3.8.2016 9:00", "4.8.2016 9:00", "5.8.2016 9:00", "6.8.2016 9:00", "7.8.2016 9:00", "8.8.2016 9:00", "9.8.2016 9:00", "10.8.2016 9:00", "11.8.2016 9:00", "12.8.2016 9:00", "13.8.2016 9:00", "14.8.2016 9:00", "15.8.2016 9:00", "16.8.2016 9:00", "17.8.2016 9:00", "18.8.2016 9:00", "19.8.2016 9:00", "20.8.2016 9:00", "21.8.2016 9:00", "22.8.2016 9:00", "23.8.2016 9:00", "24.8.2016 9:00", "25.8.2016 9:00", "26.8.2016 9:00", "27.8.2016 9:00", "28.8.2016 9:00", "29.8.2016 9:00", "30.8.2016 9:00", "31.8.2016 9:00"]

Stunde[9][8 ..12].datum		# call datum on selected Stunde-records
 => ["8.8.2016 9:00", "9.8.2016 9:00", "10.8.2016 9:00", "11.8.2016 9:00", "12.8.2016 9:00"] 

```

then you can assign appointments to these dates


lets create a simple diary

```ruby
ORD.create_vertex_class :termin
 => Termin
ORD.create_edge_class   :date_of
 => DATE_OF
DATE_OF.create from: Monat[m].tag[9].stunde[12], 
	       to: Termin.create( short: 'Mittagessen', 
				  long: 'Schweinshaxen essen mit Lieschen Müller', 
				  location: 'Hofbauhaus, München' )
 => #<DateOf:0x0000000334e038 (..) @attributes={"out"=>"#21:57", "in"=>"#41:0", (..)}> 
# create some regular events
# attach breakfirst at 9 o clock from the 10th to the 21st Day in the current month
DATE_OF.create from: Stunde[9][10..21], to: Termin.create( :short => 'Frühstück' )
 => #<DateOf:0x000000028d5688 @metadata={(..) "cluster"=>45, "record"=>8}, 
			      @attributes={"out"=>"#22:188", "in"=>"#42:0",(..)}>

t = Termin.where short: 'Frühstück'
t.in_time_of.out.first.datum
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







