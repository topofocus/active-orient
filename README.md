# ActiveOrient
Use OrientDB to persistently store dynamic Ruby-Objects and use database queries to manage even very large
datasets.

The Package ist tested with Ruby 2.2.1 and Orientdb 2.1.


To start you need a ruby 2.x Installation and a working OrientDB-Instance.  
Install the Gem the usual way

For a quick start, go to the home directory of the package and start an irb-session

```ruby
  require 'bundler/setup'
  require 'active-orient'
```

First, the Database-Server has to be specified. Then we can connect to a database.
Assuming, the server is located on localhost, we just define »default-server«
```ruby
   ActiveOrient::OrientDB.default_server= { user: 'your user', password: 'your password' }


  r = ActiveOrient::OrientDB.new  database: 'First'
   => I, [2015-08-18T09:49:18.858758 #88831]  INFO -- OrientDB#Connect: Connected to database First
   => #<ActiveOrient::OrientDB:0x000000048d0488 @res=#<RestClient::Resource:0x00000004927288 
       @url="http://localhost:2480", @block=nil, 
       @options={:user=>"xx", :password=>"***"}>, @database="First", @classes=[]> 
```

»r« is the Database-Instance itself.  Obviously the database is  empty.


Let's create some classes 

 ```ruby
    M = r.open_class          'classname'  # 
    M = r.create_class        'classname'  # creates or opens a basic document-class
    M = r.create_vertex_class 'classname'  # creates or opens a vertex-class 
    M = r.create_edge_class   'classname'  # creates or opens an edge-class, providing bidirectional links between documents

    r.delete_class   M                   # universal removal-of-the-class-method
 ```


»M« is the ActiveOrient::Model-Class itself, a constant pointing to the class-definition of the ruby-class.
Its a shortcut for »ActiveOrient::Model::{Classname} and is reused if defined elsewhere.

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
and is of TYPE ActiveOrient::Model::{classname}

As for ActiveRecord-Tables, the Class itself provides methods to inspect and to filter datasets form the database.

```ruby
  M.all   
  M.first
  M.last
```
returns an Array containing all Documents/Edges of the Class; the first and the last Record.
```ruby
  M.where  town: 'Berlin'
```
performs a query on the class and returns the result as Array

```ruby
  M.count where: { town: 'Berlin' }
```
gets the number of datasets fullfilling the search-criteria. Any parameter defining a valid
SQL-Query in Orientdb can be provided to the count, where, first and last-method.

A »normal« Query is submitted via 
```ruby
  M.get_documents projection: { projection-parameter }
		  distinct: { some parameters }
		  where: { where-parameter }
		  order: { sorting-parameters }
		  group_by: { one grouping-parameter}
		  unwind:
		  skip:
		  limit:

#  or
 query = OrientSupport::OrientQuery.new {paramter}
 M.get_documents query: query

```

Basic graph-support:



```ruby
  vertex_1 = Vertex.create  color: "blue"
  vertex_2 = Vertex.create  flower: "rose"
  Edge.create_edge attributes: { :birthday => Date.today }, from: vertex_1, to: vertex_2
```
connects the vertices and assigns the attributes to the edge


#### Links

A record in a database-class is defined by a »rid«. Every Model-Object comes with a handy »link«-method.

In OrientDB links are used to realise unidirectional  1:1 and 1:n relationships.

ActiveOrient autoloads Model-objects when they are accessed. As a consequence, 
if an Object is stored in Cluster 30 and id 2, then "#30:2" fully qualifies the ActiveOrient::Model object.

```ruby
  TestLinks = r.create_class 'Test_link_class'
  TestBase = r.create_class 'Test_base_class'

  link_document =  TestLinks.create  att: 'one attribute' 
  base_document =  TestBase.create  base: 'my_base', single_link: link_document 
```
base_document.single_link just contains the rid. When accessed, the ActiveOrient::Model::Testlinkclass-object is autoloaded and 
``` ruby
   base_document.single_link.att
```
reads the stored content of link_document. 

To store a list of links to other Database-Objects a simple Array is allocated
``` ruby
  # predefined linkmap-properties
  base_document =  TestBase.create links: []
  ( 0 .. 20 ).each{ |y|  base_document.links << TestLinks.create  nr: y  }
  end
  #or in schemaless-mode
  base_document =  TestBase.create links: (0..20).map{|y|  TestLinks.create  nr: y  }


```
base_document.links behaves like a ruby-array. 

If you got an undirectional graph

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
  --> #<ActiveOrient::Model::E1:0x000000041e4e30 
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
#### Queries
Contrary to traditional SQL-based Databases OrientDB handles  subqueries very efficient. 
In addition, OrientDB supports precompiled statements (let-Blocks).

ActiveOrient is equipped with a simple QueryGenerator: ActiveSupport::OrientQuery. 
It works in two modi: a comprehensive and a subsequent one
```ruby
  
  q =  OrientSupport::OrientQuery.new
  q.from = Vertex  
  q.where << a: 2
  q.where << 'b > 3 '
  q.distinct = :profession
  q.order =  { :name => :asc }

```
is equivalent to
```ruby
  q =  OrientSupport::OrientQuery.new :from  Vertex , 
				      :where [{ a: 2 }, 'b > 3 '],
				      :distinct  :profession,
				      :order  { :name => :asc }
  q.to_s
  => select distinct( profession ) from Vertex where a = 2 and b > 3  order by name asc
```
Both modes can be mixed.

If subqueries are nessesary, they can be introduced as OrientSupport::OrientQuery or as »let-block«.
```ruby
  q =  OrientSupport::OrientQuery.new from: 'ModelQuery'
  q.let << "$city = adress.city"
  q.where = "$city.country.name = 'Italy' OR $city.country.name = 'France'"
  q.to_s
  => select from ModelQuery let $city = adress.city where $city.country.name = 'Italy' OR $city.country.name = 'France' 
```
or
```ruby
  q =  OrientSupport::OrientQuery.new
  q.let << { a:  OrientSupport::OrientQuery.new( from: '#5:0' ) }
  q.let << { b:  OrientSupport::OrientQuery.new( from: '#5:1' ) }
  q.let << '$c= UNIONALL($a,$b) '
  q.projection << 'expand( $c )'
  q.to_s
  => select expand( $c ) let $a = ( select from #5:0 ), $b = ( select from #5:1 ), $c= UNIONALL($a,$b)
```




#### Execute SQL-Commands
Sql-commands can be executed as batch

The ActiveOrient::Query-Class provides a Query-Stack and an Records-Array which keeps the results.
The ActiveOrient::Query-Class acts as Parent-Class for aggregated Records (without a @rid), which are ActiveOrient::Model::Myquery Objects. If a Query returns a database-record, the correct ActiveOrient::Model-Class is instantiated.

```ruby
   ach = ActiveOrient::Query.new
    
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
 roq = ActiveOrient::Query.new
 roq.queries =["select name, categories.subcategories.contracts from Industries  where name containstext     …'ial'"]
 roq.execute_queries.each{|x|  puts x.name, x.categories.inspect }
 --> Basic Materials 	[["#21:1"]]
 --> Financial  	[["#21:2"]]
 --> Industrial 	[["#23:0", "#23:1"]]
```

OrientDB supports the execution of SQL-Batch-Commands. 
( http://orientdb.com/docs/2.0/orientdb.wiki/SQL-batch.html )
This is supported simply by using a Array as Argument for ActiveOrient::Query.queries

Therefor complex queries can be simplified using database-variables 
```ruby
   ach = ActiveOrient::Query.new
   ach.queries << [ "select expand( contracts )  from Openinterest"
	            "let con = select expand( contracts )  from Openinterest; ",
		    "...", ... ]
   result = ach.execute_queries 
```

The contract-documents are accessible with 
```ruby
  r.get_document '21:1'
  --><Stocks: con_id: 77680640 currency: EUR details: #18:1 exchange: SMART local_symbol: BAS 
     primary_exchange: IBIS subcategory: #14:1 symbol: BAS>
```
or
```ruby
    my_query = ActiveOrient::Query.new
    ['Contracts', 'Industries', 'Categories', 'Subcategories'].each do |table|
        my_query.queries = [ "select count(*) from #{table}"]
 
        count = my_query.execute_queries
        # count=> [#<ActiveOrient::Model::Myquery:0x00000003b317c8 
        #		@metadata={"type"=>"d", "class"=>nil, "version"=>0, "fieldTypes"=>"count=l"},
        #		@attributes={"count"=>4 } ] --> an Array with one Element, therefor count.pop 
        puts "Table #{table} \t #{count.pop.count} Datasets "
    end
    -->Table Contracts 	 	56 Datasets 
    -->Table Industries 	 8 Datasets 
    -->Table Categories 	22 Datasets 
    -->Table Subcategories 	35 Datasets 

```

Note that the fetched Object is of type »Stocks« (ActiveOrient::Model::Stocks).

The ActiveOrient-API documentation can be found here: https://github.com/orientechnologies/orientdb-docs/wiki/OrientDB-ActiveOrient
and the ActiveModel-documentation is here: http://www.rubydoc.info/gems/activemodel
 
 
 
