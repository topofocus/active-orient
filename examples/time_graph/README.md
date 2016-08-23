#Example: Time Graph

The bin-directory contains a customized console-application. 
Any libraries are included and one can start exploring the features immediately.

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
Monat --[DAY_OF]--TAG --[TIME_OF] -- Stunde
```
and populated by calling 

```ruby
CreateTime.populate_month
```

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
```

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
# attach breakfirst to 9 o clock
DATE_OF.create from: Monat[m].tag.map{|t| t.stunde[9]} to: Termin.create( :short => 'Frühstück' )
 => #<DateOf:0x000000028d5688 @metadata={(..) "cluster"=>45, "record"=>8}, 
			      @attributes={"out"=>"#22:188", "in"=>"#42:0",(..)}>
created_date =  ActiveOrient::Model.autoload_object '42:0'
 => #<Termin:0x00000003db2d80 @metadata={"type"=>"d", "class"=>"termin", "version"=>33, 
			  "fieldTypes"=>"in_date_of=g", "cluster"=>42, "record"=>0}, @d=nil, 
			  @attributes={"short"=>"'Frühstück'", "in_date_of"=>["#46:0", "#47:0", "#48:0", "#45:1", "#46:1", "#47:1", "#48:1", "#45:2", "#46:2", "#47:2", "#48:2", "#45:3", "#46:3", "#47:3", "#48:3", "#45:4", "#46:4", "#47:4", "#48:4", "#45:5", "#46:5", "#47:5", "#48:5", "#45:6", "#46:6", "#47:6", "#48:6", "#45:7", "#46:7", "#47:7", "#48:7", "#45:8"], (..)}>
created_date.in_date_of.out.map{|hour| hour.tag.datum }
 => [["0.8.2016"], ["1.8.2016"], ["2.8.2016"], ["3.8.2016"], ["4.8.2016"], ["5.8.2016"], ["6.8.2016"], ["7.8.2016"], ["8.8.2016"], ["9.8.2016"], ["10.8.2016"], ["11.8.2016"], ["12.8.2016"], ["13.8.2016"], ["14.8.2016"], ["15.8.2016"], ["16.8.2016"], ["17.8.2016"], ["18.8.2016"], ["19.8.2016"], ["20.8.2016"], ["21.8.2016"], ["22.8.2016"], ["23.8.2016"], ["24.8.2016"], ["25.8.2016"], ["26.8.2016"], ["27.8.2016"], ["28.8.2016"], ["29.8.2016"], ["30.8.2016"], ["31.8.2016"]] 






Monat[month].tag.each{|d| d.stunde.each{|s| s.termin=[]; s.save } } # populate hour-vertices 
# we append our dates to the termin-property
Monat[month].tag[9].stunde[8].termin << "Post"
Monat[month].tag[9].stunde[9].termin << "zweites Frühstück"
Monat[month].tag.each{|t| t.stunde[12].termin << "Mittag"}
```







