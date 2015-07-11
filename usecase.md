## Usecase
Below some typical features are summarized by example

Start a irb-session and initialize ActiveOrient
 ```ruby
topo@gamma:~/new_hctw$ irb
2.2.1 :001 > require './config/boot'
  Using development-environment
  -------------------- initialize -------------------- => true 
2.2.1 :002 > REST::Model.orientdb = ror = REST::OrientDB.new
    => #<REST::OrientDB:0x000000046f1a90 @res=#<RestClient::Resource:0x000000046c0af8 @url="http://localhost:2480", @block=nil, @options={:user=>"hctw", :password=>"**"}>, @database="hc_database", @classes=[]> 
```
#### Object Mapping
Lets create a class, put some content in it and perform basic oo-steps.

Attributes(Properties) do not have to be formaly declared. However it is nessessary to introduce them properly. This is done with the »attributes«-Argument during the initialisation step or via
»update«  

``` ruby
  A =  r.create_class 'my_a_class'
  => REST::Model::Myaclass
  a = A.new_document attributes: { test: 45}
  a.update set: { a_array: aa= [ 1,4,'r', :r ]  , 
                  a_hash: { :a => 'b', b: 2 } }
  a.to_human
  => <Myaclass: a_array: [1, 4, "r", :r] a_hash: {:a=>"b", :b=>2} test: 45>

```
Then the attibutes/properties can be handled as normal ruby objects ie.
 
``` ruby
  a.a_array << "a new element"
  a.a_hash[ :a_new_element ] =  "value of the new element"
  a.test += 3
  a.test =  567
  a.update
```
Objects are synchronized with the database with »update«. To revert changes, a »reload!« method is available. 

#### Contracts-Example
Assume a Database, which is defined as
```
  create class Industries
  create class Categories
  create class SubCategories
  create class OpenInterest ABSTRACT
  create class Stocks extends Contracts
  create class Futures extends Contracts
  create class Options extends Contracts
  create class Forexes extends Contracts
  create property Industries.categories linkset
  create property Categories.subcategories linkset
  create property Categories.industry link
  create property SubCategories.category link
  create property SubCategories.contracts linkset

  create property Contracts.subcategory link
  create property Contracts.details link
  create property OpenInterest.contracts linkset

```
This defines some conventional relations:

OpenInterest -> Contracts <- Subcategory <- Category <- Industry

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
2.2.1 :002 > REST::Model.orientdb = ror = REST::OrientDB.new
 => #<REST::OrientDB:0x000000046f1a90 @res=#<RestClient::Resource:0x000000046c0af8 @url="http://localhost:2480", @block=nil, @options={:user=>"hctw", :password=>"**"}>, @database="hc_database", @classes=[]> 
2.2.1 :003 > oi=  ror.create_class 'Openinterest'
 => REST::Model::Openinterest 
2.2.1 :004 > ooi = oi.all.first
 => #<REST::Model::Openinterest:0x0000000443ede8 @metadata={"type"=>"d", "class"=>"Openinterest", "version"=>5, "fieldTypes"=>"fetch_date=t,contracts=z", "cluster"=>13, "record"=>0}, @attributes={"fetch_date"=>"2015-06-02 00:00:00", "contracts"=>["#21:36", "#21:35", "#21:34", "#21:33", "#21:32", "#21:31", "#21:30", "#21:29", "#21:28", "#21:27", "#21:26", "#21:25", "#21:24", "#21:23", "#21:22", "#21:21", "#21:51", "#21:49", "#21:50", "#21:47", "#21:48", "#21:45", "#21:46", "#21:43", "#21:44", "#21:41", "#21:42", "#21:39", "#21:40", "#21:37", "#21:38", "#21:4", "#21:3", "#21:0", "#21:17", "#21:18", "#21:19", "#21:20", "#21:13", "#21:14", "#21:15", "#21:16", "#21:9", "#21:10", "#21:11", "#21:12", "#21:5", "#21:6", "#21:7", "#21:8"], "created_at"=>2015-07-01 15:27:41 +0200, "updated_at"=>2015-07-01 15:27:41 +0200}> 
2.2.1 :005 > ooi.contracts.first.subcategory.category.industry
 => #<REST::Model::Industries:0x00000004af88f0 @metadata={"type"=>"d", "class"=>"Industries", "version"=>8, "fieldTypes"=>"categories=n", "cluster"=>17, "record"=>1}, @attributes={"categories"=>["#15:13", "#15:4", "#15:1"], "name"=>"Basic Materials", "created_at"=>2015-07-01 15:27:58 +0200, "updated_at"=>2015-07-01 15:27:58 +0200}> 

2.2.1 :006 > ooi.contracts.first.subcategory.category.industry.name
 => "Basic Materials"
```


