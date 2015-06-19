# orientdb-rest
Access OrientDB from Ruby using the robust high-level REST-HTTP-API

The Package ist tested with Ruby 2.2.1 and Orientdb 2.1 (2.0).

It is written to store data, gathered by a Ruby-program ( ib-ruby in particular), into an OrientDB-Database,to query the Database in a rubish (aka activeRecord) manner and then to deal conviently with ActiveModel-Objects.

To start you need a ruby 2.x Installation.  
Clone the project and run bundle install/ bundle update,
then modify »config/connect.yml«. 

For a quick start, go to the home directory of the package and start an irb-session

then

```ruby
  require './config/boot'«
  r = REST::OrientDB.new 
  REST::Model.orientdb = r
```

Now any REST::Model-Object »knows« how to access the database.
»r« is the Database-Instance itself.

You can fetch a list of classes  
```ruby
     r.database_classes include_system_classes:true
    --> ["Car", (..), "E", "OFunction", "OIdentity", "ORIDs", "ORestricted", "ORole", "OSchedule", "OTriggered", "OUser", "Owns", "V", "_studio"]
```
 
Creation and removal of Classes  and Edges is straightforward
 ```ruby
    r.create_class        classname  # creates a basic document-class
    r.create_vertex_class classname  # creates a vertex-class 
    r.create_edge_class   classname  # creates an edge-class, providing bidirectional links between documents

    r.delete_class        classname  # universal removal-class-method
    
    or
    model =  r.create_class classname
    (...)
    r.delete_class model
 ```

»model« is the REST::Model-Class itself, a constant pointing to the class-definition.
REST::Model-Instances represent  records (aka documents/vertices/edges) of the database.

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
 or
 ```ruby
 model.create_property field: 'symbol'
 model.create_property field: 'con_id', type: 'integer'
 model.create_property field: 'details', type: 'link', other_class: 'Contracts'
 ```



Documents are easily created, updated, removed 
 ```ruby
  record = model.new_document  attributes: { con_id: 345, symbol: 'EWQZ' }
  # (or)
  record = REST::Model::Contracts.new_document :attributes => { :con_id => 345, :symbol => 'EWQZ' }

  record.con_id =  346
  record.update

  record.delete

 ```

Multible Documents can updated and deleted query based 

 ```ruby
  r.update_or_create_documents o_class: model, set: {con_id= 345} , where: {symbol: 'EWZ'} 
  r.delete_documents o_class: model , where: { con_id: 345, symbol: 'EWQZ' }

 ```

#### Active Model interface
 
Every OrientDB-Database-Class is mirrord as Ruby-Class. The Class itself is defined dynamically by
```ruby
  vertex_class =  r.create_vertex_class classname 
  edge_class   =  r.create_edge_class   classname 
  
```
and of TYPE REST::Model::{classname}

If a document is created, an Instance to the Class is returned.
If the database is queried, a list of Instances to the Class is returned.

As for ActiveRecord-Tables, the Class itself  provides methods to inspect and to filter datasets 
form the database. »class« is equivalent to »REST::Model::{classname}«

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
  edge_class.create_edge attributes: { :birthday => Date.today }, from: '#23:45', to: '#12:21'
  # (or)
  vertex1 = r.get_document '#23:45'
  edge_class.create_edge attributes: { :birthday => Date.today }, from: vertex_1, to: vertex_2
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
#### Links

Links are followed and autoloaded.  This includes edges.
```ruby
  link_class = r.create_class 'Testlinkclass'
  base_class = r.create_class 'Testbaseclass'
  base_class.create_property field: 'to_link_class', type: 'link', linked_class: link_class
  base_class.create_property field: 'to_link_set', type: 'linkset', linked_class: link_class

  link_document =  link_class.new_document attributes: { att: 'one attribute' }
  base_document =  base_class.new_document attributes: { base: 'my_base', to_link_class: link_document.link }

  base_document.to_link_class => REST::Model::Testlinkclass ....

  (0..20).each{|y| base_document.add_linkset( :to_link_set, 
				  link_class.new_document( attributes: { nr: y } ) )  }

  base_document.to_link_set[19] => REST::Model::Testlinkclass ...

```

If you got an undirectional graph

   a --> b ---> c --> d

then the graphelements can be explored by joining the objects ( a.b.c.d ), or (a.b[5].c[9].d )

#### Edges

Edges are easily inserted between documents (vertexes)
```ruby
  vertex_class = r.create_vertex_class 'D1'
  edge_class = r.create_edge_class 'E1'

  start =  REST::Model:D1.new_document attributes:  { something: 'nice' }
  end   =  REST::Model::D1.new_document attributes: { something: 'not_nice' }
  the_edge = REST::Model::E1.create_edge(  attributes:  { transform_to: 'very bad' },
				      from: start,
				      to: end	)

  (...)
  the_edge.delete
```

There is a basic support for traversals throught a graph.
The Edges are accessed  by their names (downcase).

```ruby
  start.e1[0]
  --> #<REST::Model::E1:0x000000041e4e30 
	@metadata={"type"=>"d", "class"=>"E1", "version"=>60, "fieldTypes"=>"out=x,in=x", 
		   "cluster"=>16, "record"=>43}, 
        @attributes={"out"=>"#31:23", "in"=>"#31:15", "transform_to"=>"very bad" }>
```
The Attributes "in" and "out" can be used to move across the graph
```ruby
   start.e1[0].out.something 
   ---> "not_nice
   start.e1[0].in.something 
   ---> "nice
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
 
 
 
#### Ruby-Objects

OrientDB-Classes are mapped to Ruby-Active-Model-Classes. These can further specified like 
ActiveRecord-Models.

Assume, you created the hierachie
```
    create class Contracts ABSTRACT
    create class Stocks extends Contracts
```
Then you can intialize the ActiveModel-Classes either by
```ruby
   r.create_class 'Contracts'
   r.create_class 'Stocks'
``` 
or
```ruby
  class REST::Model::Contracts < REST::Model
      def a_method
      ...
      end
   end
   
  class REST::Model::Stocks < REST::Model::Contracts
      def a_method
      ...
      end
  end
```


