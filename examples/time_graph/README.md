Example Time Graph

The bin-directory contains a customized console-application. 
Any libraries are included and one can start exploring the features immediately.

The Database is initialized by calling

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
month =  Date.today.month  # current month

Monat[month].tag.map &:value
=> [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31] 

Monat[month].tag[9].stunde[9].value
=> 9

Monat[month].tag[9].next.datum
 => "10.8.2016" 
```

lets create a simple diary

```ruby
Monat[month].tag.each{|d| d.stunde.each{|s| s.termin=[]; s.save } } # populate hour-vertices 
# we append our dates to the termin-property
Monat[month].tag[9].stunde[8].termin << "Post"
Monat[month].tag[9].stunde[9].termin << "zweites Frühstück"
Monat[month].tag.each{|t| t.stunde[12].termin << "Mittag"}
```







