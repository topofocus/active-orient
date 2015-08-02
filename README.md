# ActiveOrient
Use OrientDB to persistently store dynamic Ruby-Objects and use database queries to manage even very large
datasets.

The Package ist tested with Ruby 2.2.1 and Orientdb 2.1 (2.0).


To start you need a ruby 2.x Installation and a working OrientDB-Instance.  
Clone the project and run bundle install/ bundle update,
then modify »config/connect.yml«. 
Its adviserable to generate the rdoc-documentation with executing
```
rdoc 
```
from the source directory of AcitiveOrient and then to load the doc-directory into any browser.

For a quick start, go to the home directory of the package and start an irb-session

then

```ruby
  require './config/boot'
  r = REST::OrientDB.new  database: 'First'
   => #<REST::OrientDB:0x000000048d0488 @res=#<RestClient::Resource:0x00000004927288 
       @url="http://localhost:2480", @block=nil, 
       @options={:user=>"xx", :password=>"***"}>, @database="First", @classes=[]> 
```

»r« is the Database-Instance itself.  The database is empty.

Let's create some classes 

 ```ruby
    M = r.open_class          'classname'  # 
    M = r.create_class        'classname'  # creates or opens a basic document-class
    M = r.create_vertex_class 'classname'  # creates or opens a vertex-class 
    M = r.create_edge_class   'classname'  # creates or opens an edge-class, providing bidirectional links between documents

    r.delete_class   M                   # universal removal-class-method
 ```


»M« is the REST::Model-Class itself, a constant pointing to the class-definition of the ruby-class.
Its a shortcut for »REST::Model::{Classname} and is reused if defined elsewhere.

If a schema is used, properties can be created and retrieved as well
 ```ruby
  r.create_properties( M ) do
     {	symbol: { propertyType: 'STRING' },
		con_id: { propertyType: 'INTEGER' },
       	details: { propertyType: 'LINK', linkedClass: 'Contracts' }
      }

  r.get_class_properties  M 
 ```
 or
 ```ruby
 M.create_property  'symbol'
 M.create_property  'con_id', type: 'integer'
 M.create_property  'details', type: 'link', other_class: 'Contracts'
 ```

#### Active Model interface
 
Every OrientDB-Database-Class is mirrord as Ruby-Class. The Class itself is defined  by
```ruby
  M =  r.create_class 'classname' 
  M =  r.create_class { superclass_name:  'classname'  }
  Vertex =  r.create_vertex_class 'classname' 
  Edge   =  r.create_edge_class   'classname' 
```
and is of TYPE REST::Model::{classname}

As for ActiveRecord-Tables, the Class itself provides methods to inspect and to filter datasets form the database.

```ruby
  M.all   
  M.first
  M.last
```
returns an Array containing all Documents/Edges of the Class, the first and the last Record.
```ruby
  M.where  town: 'Berlin'
```
performs a query on the class and returns the result as Array

```ruby
  M.count where: { town: 'Berlin' }
```
gets the number of datasets fullfilling the search-criteria

```ruby
  vertex_1 = Vertex.create  color: "blue"
  vertex_2 = Vertex.create  flower: "rose"
  Edge.create_edge attributes: { :birthday => Date.today }, from: vertex_1, to: vertex_2
```
connects the vertices and assigns the attributes to the edge


#### Links

A record in a database-class is defined by a »rid«. Every Model-Object comes with a handy »link«-method.

In OrientDB links are used to realise unidirectional  1:1 and 1:n relationships.

ActiveOrient autoloads Model-objects.

If an Object is stored in Cluster 30 and id 2, then "#30:2" fully qualifies the REST::Model object.

```ruby
  TestLinks = r.create_class 'Test_link_class'
  TestBase = r.create_class 'Test_base_class'

  link_document =  TestLinks.create  att: 'one attribute' 
  base_document =  TestBase.create  base: 'my_base', single_link: link_document 
```
base_document.single_link just contains the rid. When accessed, the REST::Model::Testlinkclass-object is autoloaded and 
``` ruby
   base_document.single_link.att
```
reads the stored content of link_document. 

To store a list of links to other Database-Objects a simple Array is allocated
``` ruby
  base_document =  TestBase.create links: []
  ( 0 .. 20 ).each{ |y|  base_document.links << TestLinks.create  nr: y  }
  end

```
base_document.links behaves like a ruby-array. 

As a consequence, if you got an undirectional graph

   a --> b ---> c --> d

the graphelements can be explored by joining the objects ( a.b.c.d ), or (a.b[5].c[9].d )

#### Edges

Edges are easily handled
```ruby
  Vertex = r.create_vertex_class 'd1'
  Eedge = r.create_edge_class   'e1'

  start =  Vertex.create  something: 'nice' 
  the_end   =  Vertex.create  something: 'not_nice' 
  the_edge = Edge.create_edge  attributes:  { transform_to: 'very bad' },
			       from: start,
			       to: the_end
 
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
 
 
 
