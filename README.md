# orientdb-rest
Access OrientDB from Ruby without accessing third-party-libraries.

Orientdb-Rest is based on ActiveModels and the REST-HTTP-Api of OrientDB. This high level API ist most likely robust.
The Package ist tested with Ruby 2.2.1 and Orientdb 2.1 (2.0).

Orientdb-rest is written to store data, gathered by a Ruby-program ( ib-ruby in particular), into an OrientDB-Database,to query the Database in a rubish (aka activeRecord) manner and then to deal conviently with ActiveModel-Objects.

To start you need a ruby 2.x Installation, 
clone the project and run bundle install and bundle update,
then modify »config/connect.yml« 

In a irb-session you need to
»require './config/boot'«


It's initialized by

```ruby
 REST::OrientDB.logger = REST::Model.logger = Logger.new('/dev/stdout') # or your customized-logger
 r = REST::OrientDB.new 
```

Then the database has to be assigned to any REST::Model-Object:
```ruby
REST::Model.orientdb = r
```
Note: If the working database is changed (by r.change_database newname) there is no need to reassign the database to Model-Objects.

You can fetch a list of classes  and some properties by
 ``` ruby
    r.get_classes 'name', 'superClass' (, further attributes )
    --> [ { 'name' => class_name , 'superClass' => superClass_name  }, { .. } ]
 ```
 
 or simply 
```ruby
     r.database_classes include_system_classes:true
    --> ["Car", (..), "E", "OFunction", "OIdentity", "ORIDs", "ORestricted", "ORole", "OSchedule", "OTriggered", "OUser", "Owns", "V", "_studio"]
```
 
Creation and removal of Classes  and Edges is straightforward
 ```ruby
    r.create_class        classname  # creates a document-class, also used as vertex
    r.create_edge_class   classname  # creates an edge-class, providing bidirectional links between documents

    r.delete_class        classname  # universal removal-class
    
    or
    model =  r.create_class classname
    (...)
    r.delete_class model
 ```

»model« is the REST::Model-Class itself, a constant pointing to the class-definition.
A model-class has several Instances, refering to the records (aka documents/edges) in the database.

It is used as argument to several methods, providing the class-name to operate on
and as reference to instantiate the correct REST::Model-Object.

If a schema is used, Properties can be created and retrieved as well
 ```ruby
  r.create_properties( o_class: model ) do
     {	symbol: { propertyType: 'STRING' },
	con_id: { propertyType: 'INTEGER' },
       details: { propertyType: 'LINK', linkedClass: 'Contracts' }
      }

  r.get_class_properties o_class: model 
 ```
 
Documents are easily created, updated, removed and queried either on a SQL-query-base or on a activeRecord-style
 ```ruby
  record = r.create_document o_class: model , attributes: { con_id: 345, symbol: 'EWQZ' }
  --> REST::Model::{model}-object
 ```
  creates a record in the classname-class 

 ```ruby
  record = r.update_documents o_class: model , set: { con_id: 346 },
		      where: { symbol: 'EWQZ' } 

 ```
 updates the database based on a query, 
 »record.update« saves a dirty record to the database.
 

 ```ruby
  records = r.get_documents o_class: model , where: { con_id: 345, symbol: 'EWQZ' }
  record  = r.get_document rid                       # rid can be either #x:y or x:y 

 ```
 queries the database accordantly and

 ```ruby
  r.delete_documents o_class: model , where: { con_id: 345, symbol: 'EWQZ' }

 ```
 completes the circle

#### Active Model interface
 
Every OrientDB-Database-Class is mirrord as Ruby-Class. The Class itself is defined dynamically by
```ruby
  vertex_class =  r.create_class        classname 
  edge_class   =  r.create_edge_class   classname 
  
```
and of TYPE REST::Model::{classname}

If a document is created, an Instance to the Class is returned.
If the database is queried, a list of Instances to the Class is returned.

As for ActiveRecord-Tables, the Class itself  provides methods to inspect and to filter datasets form the database

```ruby
  class.all 
```
returns an Array with all Documents/Edges of the Class.
```ruby
  class.where attributes: { list of query-criteria } 
```
performs a query on the class and returns the result as Array

```ruby
  class.count attributes: { town: 'Berlin' }
```
gets the number of datasets fullfilling the search-criteria

```ruby
  edge_class.create_edge attributes: { :birthday => Date.today }, from: '#23:45' to '#12:21'
```
connects the documents specified by the rid's with the edge and assigns the attributes to the edge

The instantiated REST::Model-Objects can be treated as expected:
```ruby
  new_document =  class.new_document attributes: { town: 'Berlin' }
  # new_document builds the document in the database and returns the instantiated Model-Instance.
  # We don't handle pure ruby REST:Model-Instances and thus don't have to deal with create and save. 
  new_document.update set: { town: "Paris" }
  new_document.delete
```

#### Execute SQL-Commands
At least - sql-commands can be executed as batch

The REST::Query-Class provides a Query-Stack and an Records-Array which keeps the results.
The REST::Query-Class acts as Parent-Class for aggregated Records (without a @rid), which are REST::Model::Myquery Objects. If a Query returns a database-record, the correct REST::Model-Class is instantiated.

```ruby
   ach = REST::Query.new
    
   ach.queries << 'create class Contracts ABSTRACT'
   ach.queries << 'create property Contracts.subcategory link'
   ach.queries << 'create property Contracts.details link'
   ach.queries << 'create class Stocks extends Contracts'
   ach.queries << 'create class Futures extends Contracts'
   result = ach.execute_queries transaction: false
   
   

```
  queries the database as demonstrated above. In addition, the generated query itself is added to the »queries«-Stack and the result can be found in sample_query.records.
  
This feature can be used as a substitute for simple functions

```ruby
 roq = REST::Query.new
 roq.queries =["select name, categories.subcategories.contracts from Industries  where name containstext     …'ial'"]
 roq.execute_queries.each{|x|  puts x.name, x.categories.inspect }
 --> Basic Materials 	[["#21:1"]]
 --> Financial  	[["#21:2"]]
 --> Industrial 	[["#23:0", "#23:1"]]
```

OrientDB supports the execution of SQL-Batch-Commands. 
( http://orientdb.com/docs/2.0/orientdb.wiki/SQL-batch.html )
This is supported simply by using a Array as Argument for REST::Query.queries

Therefor complex queries can be simplified using database-variables 
```ruby
   ach = REST::Query.new
   ach.queries << [ "select expand( contracts )  from Openinterest"
	            "let con = select expand( contracts )  from Openinterest; ",
		    "...", ... ]
   result = ach.execute_queries 
```

The contract-documents can easily be fetched with 
```ruby
  r.get_document '21:1'
  --><Stocks: con_id: 77680640 currency: EUR details: #18:1 exchange: SMART local_symbol: BAS 
     primary_exchange: IBIS subcategory: #14:1 symbol: BAS>
```
or
```ruby
    ror_query = REST::Query.new
    ['Contracts', 'Industries', 'Categories', 'Subcategories'].each do |table|
        ror_query.queries = [ "select count(*) from #{table}"]
 
        count = ror_query.execute_queries
        # count=> [#<REST::Model::Myquery:0x00000003b317c8 
        #		@metadata={"type"=>"d", "class"=>nil, "version"=>0, "fieldTypes"=>"count=l"},
        #		@attributes={"count"=>4 } ] --> a Array with one Element, therefor count.pop 
        puts "Table #{table} \t #{count.pop.count} Datasets "
    end
    -->Table Contracts 	 	56 Datasets 
    -->Table Industries 	 8 Datasets 
    -->Table Categories 	22 Datasets 
    -->Table Subcategories 	35 Datasets 

```

Note that the fetched Object is of type »Stocks« (REST::Model::Stocks).

The REST-API documentation can be found here: https://github.com/orientechnologies/orientdb-docs/wiki/OrientDB-REST
and the ActiveModel-documentation is here: http://www.rubydoc.info/gems/activemodel
 
 
 
 
 


