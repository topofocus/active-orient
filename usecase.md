## Usecase
Below some typical features are summarized by example

Initialize ActiveOrient by calling »bin/actibe-orient-console t«.
This connects to the Test-Database, specified in »config/connect.yml«.

 ```bash
 topo@gamma:~/activeorient/bin$ ./active-orient-console t
 Using test-environment
 30.06.(21:36:09) INFO->OrientDB#Connect:..:Connected to database tempera
 ORD points to the REST-Instance
 Allocated Classes (Hierarchy)
 -----------------------------------
 ---
 -   E
 - - V
   - - a
     - b
     - c

```
The database is almost empty. "E" and "V" are base classes for Edges and Vertices.
"a,b,c" are Vertex-Classes. 
```ruby
A,B,C =  * ORD.create_classes( [ :a, :b, :c ] ){ :v } 
```
creates them with a single statement and assigns them to Ruby-classes "A","B" and "C". 

#### Object Mapping
Lets create a class, put some content in it and perform basic oo-steps.

Attributes(Properties) do not have to be formaly declared. One can save any Object, which
provides a 'to_orient' method. Base-Classes are supported out of the box.
»update«  

``` ruby
  A =  ORD.create_class 'my_a_class'
  => ActiveOrient::Model::MyAClass
  a = A.create test: 45
  a.update set: { a_array: aa= [ 1,4,'r' ]  , 
                  a_hash: { :a => 'b', b: 2 } }
  a.to_human
  => <MyAClass: a_array: [1, 4, r], a_hash: { a => b , b =>2}, test: 45> 

```
**Notice** Ruby-Symbols are converted to Strings and masked as ":{symbol}:".

Attibutes/properties of the Database-Record  can be handled as normal ruby objects, ie.
 
``` ruby
  a.a_array << "a new element"                                     #  changes are updated in the DB, calling »update« is not nesessary
  a.a_hash[ :a_new_element ] =  "value of the new element"         #  changes are local, »update« stores them in the DB
  a.test += 3
  a.test =  567
  a.update
```

#### Contracts-Example
Assume a Database, which is defined as
```
  ORD.create_classes [ :Industry, :Category, :SubCategory ]
  ORD.create_class  :OpenInterest, abstract: true
  ORD.create_classes { :Contract => [ :Stock, Future, Option, Forex ]}
  ORD.create_property Industry.categories linkset
  ORD.create_property Category.subcategories linkset
  ORD.create_property Category.industry link
  ORD.create_property SubCategory.category link
  ORD.create_property SubCategory.contracts linkset

  ORD.create_property Contracts.subcategory link
  ORD.create_property Contracts.details link
  ORD.create_property OpenInterest.contracts linkset

```
This defines some conventional relations:

OpenInterest -> Contract <- Subcategory <- Category <- Industry

with some oo-Behavior
```ruby
2.2.1 :003 > ror.class_hierachie base_class: 'Contracts'
 => ["Forexes", "Futures", "Options", "Stocks"] 
```

then the following ORM-behavior is implemented:
 ```ruby
topo@gamma:~/new_hctw$ irb
2.2.1 :001 > require './config/boot'
  Using development-environment
  -------------------- initialize -------------------- => true 
2.2.1 :002 > ActiveOrient::Model.orientdb = ror = ActiveOrient::OrientDB.new
 => #<ActiveOrient::OrientDB:0x000000046f1a90 @res=#<RestClient::Resource:0x000000046c0af8 @url="http://localhost:2480", @block=nil, @options={:user=>"hctw", :password=>"**"}>, @database="hc_database", @classes=[]> 
2.2.1 :003 > OpenInterest =  ror.open_class 'Openinterest'
 => ActiveOrient::Model::Openinterest 
2.2.1 :004 > first_open_interest = OpenInterest.first
 => #<ActiveOrient::Model::Openinterest:0x0000000443ede8 @metadata={"type"=>"d", "class"=>"Openinterest", "version"=>5, "fieldTypes"=>"fetch_date=t,contracts=z", "cluster"=>13, "record"=>0}, @attributes={"fetch_date"=>"2015-06-02 00:00:00", "contracts"=>["#21:36", "#21:35", "#21:34", "#21:33", "#21:32", "#21:31", "#21:30", "#21:29", "#21:28", "#21:27", "#21:26", "#21:25", "#21:24", "#21:23", "#21:22", "#21:21", "#21:51", "#21:49", "#21:50", "#21:47", "#21:48", "#21:45", "#21:46", "#21:43", "#21:44", "#21:41", "#21:42", "#21:39", "#21:40", "#21:37", "#21:38", "#21:4", "#21:3", "#21:0", "#21:17", "#21:18", "#21:19", "#21:20", "#21:13", "#21:14", "#21:15", "#21:16", "#21:9", "#21:10", "#21:11", "#21:12", "#21:5", "#21:6", "#21:7", "#21:8"], "created_at"=>2015-07-01 15:27:41 +0200, "updated_at"=>2015-07-01 15:27:41 +0200}> 
2.2.1 :005 > first_open_interest.contracts.first.subcategory.category.industry
 => #<ActiveOrient::Model::Industries:0x00000004af88f0 @metadata={"type"=>"d", "class"=>"Industries", "version"=>8, "fieldTypes"=>"categories=n", "cluster"=>17, "record"=>1}, @attributes={"categories"=>["#15:13", "#15:4", "#15:1"], "name"=>"Basic Materials", "created_at"=>2015-07-01 15:27:58 +0200, "updated_at"=>2015-07-01 15:27:58 +0200}> 

2.2.1 :006 > first_open_interest.contracts.first.subcategory.category.industry.name
 => "Basic Materials"
```


