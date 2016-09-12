The Time-Graph Example is outsourced  and lives as a seperate gem.

https://github.com/topofocus/orientdb_time_graph

from the readme: 

# Time Graph

The bin-directory contains a customized console-application. 
Any libraries are included and one can start exploring the features immediately.

*Prerequisites* : 
* Run "Bundle install" and "Bundle update"
* customize config/connect.yml

**or** start a new project and include the gem in sthe usual manner.

To play around, start the console by
```
  cd bin
  ./active-orient-console t  # test-modus
```
The Database is automatically initialized and the following hierarchy is build:

```ruby
- E				# ruby-class
- - month_of		      TG::MONTH_OF
- - day_of		      TG::DAY_OF
- - time_of		      TG::TIME_OF
- - grid_of		      TG::GRID_OF
- V
- - time_base		      TG::TimeBase
- - - jahr		      TG::Jahr
- - - monat		      TG::Monat
- - - stunde		      TG::Stunde
- - - tag		      TG::Tag
```
This Graph is realized

```ruby
Jahr -- [Month_of] -- Monat --[DAY_OF]-- Tag --[TIME_OF]-- Stunde
```
and populated by calling 

```ruby
TG::TimeGraph.populate( a single year or a range )  # default: 1900 .. 2050
```
If only on year is specified, a Monat--Tag--Stunde-Grid is build, otherwise a Jahr--Monat--Tag one.
You can check the Status by calling 

```ruby
TG::TimeGraph.populate 2000 -2003
TG.info
-------------- TIME GRAPH ------------------
Allocated Years : 
2000; 2001; 2002; 2003 

```
In the Model-directory, customized methods simplify the usage of the graph.

Some Examples:
Assuming, you build a standard day-based grid

```ruby

include TG					# we can omit the TG prefix

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

To filter datasets in that way, anything represented is queried from the database. In contrast to
a pure ruby implementation, this works for small and large grid's.

Obviously, you can do neat ruby-array playings, which are limited to the usual sizes.
For example. As »TAG[31]« returns an array, the elements can be treated with ruby flavour:

```ruby

Tag[31][2..4].datum  # display three months with 31 days 
 => ["31.10.1901", "31.1.1902", "31.5.1902"]

```
First all Tag-Objects with the Value 31 are queried. This gives »Jan, Mar, May ..«. Then one can inspect the array, in this case by slicing a range.

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

## Horizontal Connections

Besides the hierarchically TimeGraph »Jahr <-->Monat <--> Tag <--> Stunde«  the Vertices are connected
horizontally via »grid_to«-Edges. This enables an easy access to the neighbours.

On the TG::TimeBase-Level a method »environment« is implemented, that gathers the adjacent vertices 
via traverse.

``` ruby
start =  TG::Jahr[2000].monat(4).tag(7).first.first
start.environment(3).datum
 => ["4.4.2000", "5.4.2000", "6.4.2000", "7.4.2000", "8.4.2000", "9.4.2000", "10.4.2000"] 

2.3.1 :003 > start.environment(3,4).datum
 => ["4.4.2000", "5.4.2000", "6.4.2000", "7.4.2000", "8.4.2000", "9.4.2000", "10.4.2000", "11.4.2000"] 
 
start.environment(0,3).datum
 => ["7.4.2000", "8.4.2000", "9.4.2000", "10.4.2000"] 
```



## Diary

lets create a simple diary

```ruby
include TG
TimeiGraph.populate 2016
ORD.create_vertex_class :termin
 => Termin
ORD.create_edge_class   :date_of
 => DATE_OF
DATE_OF.uniq_index	# put contrains to the edge-class, accept only one entry per item 

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



