# ActiveOrient
Use OrientDB to persistently store dynamic Ruby-Objects and use database queries to manage even very large
datasets.

The Package is tested with Ruby 2.3.1 and OrientDB 2.1.13.
It works with OrientDB2.2. 
However, the Model#Last-method incompatible.
Use Model#all.last as Workaround.

To start you need a ruby 2.x Installation and a working OrientDB-Instance.  
Install the Gem the usual way.

For a quick start clone the project, call bundle install + bundle update, update config/connect.yml  and start an irb-session 

```ruby
  require 'config/boot'
  require 'active-orient'
  ORD = ActiveOrient::OrientDB.new database: 'OrientTest'
  => #<ActiveOrient::OrientDB:0x00000002f924d0 @res=#<RestClient::Resource:0x00000002f922c8 @url="http://localhost:2480", @block=nil, @options={:user=>(...)}, {"name"=>"V", "superClass"=>""}], @classes=["E", "OSequence", "V"]> 
```


»ORD« is the Database-Instance itself. Obviously the database is empty.


Let's create some classes

 ```ruby
    M = ORD.open_class          'Classname'  #
    M = ORD.create_class        'ClassDocumentName'  # creates or opens a basic document-class
    M = ORD.create_vertex_class 'ClassVertexName'  # creates or opens a vertex-class
    M = ORD.create_edge_class   'ClassEdgeName'  # creates or opens an edge-class, providing bidirectional links between documents

    ORD.delete_class M                   # universal removal-of-the-class-method
 ```

*Note*: As in Ruby, we use the convention that a class needs to be defined with a capital letter.

»M« is the ActiveOrient::Model-Class itself, a constant pointing to the class-definition of the ruby-class.
It's a shortcut for »ActiveOrient::Model::{Classname}«.

If a schema is used, properties can be created and retrieved as well

 ```ruby
    ORD.create_properties(M) do
    {
      symbol: {propertyType: 'STRING' },
		  con_id: {propertyType: 'INTEGER' },
      details: {propertyType: 'LINK', linkedClass: 'Contracts' }
    }

  ORD.get_class_properties  M
 ```
 or

 ```ruby
 M.create_property 'symbol'
 M.create_property 'con_id', type: 'integer'
 M.create_property 'details', type: 'link', other_class: 'Contracts'
 ```

(Experimental) You can assign a property, directly when you create a class.

```ruby
  M = ORD.create_vertex_class "Hour", properties: {value_string: {type: :string}, value: {type: :integer}}
```

(Experimental) You can put restrictions on your properties with the command "alter_property":

```ruby
  M.alter_property property: "value", attribute: "MIN", alteration: 0
  M.alter_property property: "value", attribute: "MAX", alteration: 23
```

#### Active Model interface

Every OrientDB-Database-Class is mirrored as Ruby-Class. The Class itself is defined  by
```ruby
  M = ORD.create_class 'Classname'
  M = ORD.create_class('Classname'){superclass_name: 'SuperClassname'}
  A,B,C = * ORD.create_classes( [ :a, :b, :c ] )
  Vertex = ORD.create_vertex_class 'VertexClassname'
  Edge   = ORD.create_edge_class 'EdgeClassname'
```
and is of TYPE ActiveOrient::Model::{Classname}

Object-Inherence is maintained, thus
```ruby
  ORD.create_vertex_class :f
  M = ORD.create_class( :m ){ :f }
  N = ORD.create_class( :n ){ :f }

```
allocates the following class-hierarchy:
```ruby
class ActiveOrient::Model:F < ActiveOrient::Model:V
end
class ActiveOrient::Model:M < ActiveOrient::Model:F
end
class ActiveOrient::Model:N < ActiveOrient::Model:F
end
```
M and N are Vertexes and inherent methods (and properties) from  F

As for ActiveRecord-Tables, the Class itself provides methods to inspect and to filter datasets form the database.

```ruby
  M.all   
  M.first
  M.last
  M.where town: 'Berlin'

  M.count where: { town: 'Berlin' }
```
»count« gets the number of datasets fulfilling the search-criteria. Any parameter defining a valid SQL-Query in Orientdb can be provided to the »count«, »where«, »first« and »last«-method.

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
  Edge.create_edge attributes: {:birthday => Date.today }, from: vertex_1, to: vertex_2
```
It connects the vertexes and assigns the attributes to the edge.

#### Links

A record in a database-class is defined by a »rid«. If this is stored in a class, a link is set.
In OrientDB links are used to realize unidirectional 1:1 and 1:n relationships.

ActiveOrient autoloads Model-objects when they are accessed. Example:
If an Object is stored in Cluster 30 and id 2, then "#30:2" fully qualifies the ActiveOrient::Model object and sets the 
link if stored somewhere.

```ruby
  TestLinks = ORD.create_class 'Test_link_class'
  TestBase =  ORD.create_class 'Test_base_class'

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
  (0 .. 20).each{|y| base_document.links << TestLinks.create  nr: y}
  end
  #or in schemaless-mode
  base_document = TestBase.create links: (0..20).map{|y| TestLinks.create nr: y}
```
base_document.links behaves like a ruby-array.

If you got an undirectional graph

   a --> b ---> c --> d

the graph elements can be explored by joining the objects (a[6].b[5].c[9].d)

#### Edges
Edges provide bidirectional Links. They are easily handled
```ruby
  Vertex = ORD.create_vertex_class 'd1'
  Edge = ORD.create_edge_class   'e1'

  start = Vertex.create something: 'nice'
  the_end  =  Vertex.create something: 'not_nice'
  the_edge = Edge.create_edge attributes: {transform_to: 'very bad'},
			       from: start,
			       to: the_end

  (...)
  the_edge.delete # To delete the edge
```
The create_edge-Method takes a block. Then all statements are transmitted in batch-mode.
Assume, Vertex1 and Vertex2 are Vertex-Classes and TheEdge is an Edge-Class, then
```ruby
  record1 = (1 .. 100).map{|y| Vertex1.create_document attributes:{ testentry: y } }
  record2 = (:a .. :z).map{|y| Vertex2.create_document attributes:{ testentry: y } }
  edges = ORD.create_edge TheEdge, attributes: { study: 'Experiment1'} do  | attributes |
    ('a'.ord .. 'z'.ord).map do |o| 
	  { from: record1.find{|x| x.testentry == o },
	    to:  record2.find{ |x| x.testentry.ord == o },
	    attributes: attributes.merge( key: o.chr ) }
      end  
```
connects the vertices and provides a variable "key" and a common "study" attribute to each edge.

There is a basic support for traversals through a graph.
The Edges are accessed  by their names (downcase).
```ruby
  start = Vertex.get_documents where: {something: "nice"}
  start[0].e1[0]
  --> #<ActiveOrient::Model::E1:0x000000041e4e30	@metadata={"type"=>"d", "class"=>"E1", "version"=>60, "fieldTypes"=>"out=x,in=x", "cluster"=>16, "record"=>43}, @attributes={"out"=>"#31:23", "in"=>"#31:15", "transform_to"=>"very bad" }>
```

The Attributes "in" and "out" can be used to move across the graph

```ruby
   start[0].e1[0].out.something
   # ---> "not_nice"
   start[0].e1[0].in.something
   # ---> "nice"
```

(Experimental) In alternative you can "humanize" your code in the following way:

```ruby
   Vertex.add_edge_link name: "ends", direction "out", edge: "the_edge"
   start.ends.something # <-- Similar output as start[0].e1[0].out.something
```

#### Queries

Contrary to traditional SQL-based Databases OrientDB handles sub-queries very efficiently. In addition, OrientDB supports precompiled statements (let-Blocks).

ActiveOrient is equipped with a simple QueryGenerator: ActiveSupport::OrientQuery.
It works in two ways: a comprehensive and a subsequent one

```ruby

  q =  OrientSupport::OrientQuery.new
  q.from = Vertex     # If a constant is used, then the correspending
		      # ActiveOrient::Model-class is refered
  q.where << a: 2
  q.where << 'b > 3 '
  q.distinct = :profession
  q.order = {:name => :asc}

```
is equivalent to

```ruby
  q =  OrientSupport::OrientQuery.new from:  Vertex ,
				      where: [{ a: 2 }, 'b > 3 '],
				      distinct:  :profession,
				      order:  { :name => :asc }
  q.to_s
  => select distinct( profession ) from Vertex where a = 2 and b > 3  order by name asc
```

Both eayss can be mixed.

If sub-queries are necessary, they can be introduced as OrientSupport::OrientQuery or as »let-block«.

```ruby
  OQ = OrientSupport::OrientQuery
  q = OQ.new from: 'ModelQuery'
  q.let << "$city = adress.city"
  q.where = "$city.country.name = 'Italy' OR $city.country.name = 'France'"
  q.to_s
  # => select from ModelQuery let $city = adress.city where $city.country.name = 'Italy' OR $city.country.name = 'France'
```

or

```ruby
  q =  OQ.new
  q.let << {a: OrientSupport::OrientQuery.new( from: '#5:0' ) }
  q.let << {b: OrientSupport::OrientQuery.new( from: '#5:1' ) }
  q.let << '$c= UNIONALL($a,$b) '
  q.projection << 'expand( $c )'
  q.to_s  # => select expand( $c ) let $a = ( select from #5:0 ), $b = ( select from #5:1 ), $c= UNIONALL($a,$b)
```

or

```ruby
  OpenInterest = ORD.open_class 'Openinterest'
  last_12_open_interest_records = OQ.new from: OpenInterest, order: { fetch_date: :desc } , limit: 12
  bunch_of_contracts =  OQ.new from: last_12_open_interest_records, projection: 'expand( contracts )'
  distinct_contracts = OQ.new from: bunch_of_contracts, projection: 'expand( distinct(@rid) )'

  distinct_contracts.to_s
   => "select expand( distinct(@rid) ) from ( select expand( contracts ) from ( select  from Openinterest order by fetch_date desc limit 12 ) ) "

  cq = ORD.get_documents query: distinct_contracts
```
#### Execute SQL-Commands

Sql-commands can be executed as batch

The ActiveOrient::Query-Class provides a Query-Stack and a Records-Array which keeps the results. The ActiveOrient::Query-Class acts as Parent-Class for aggregated Records (without a \@rid), which are ActiveOrient::Model::Myquery Objects. If a Query returns a database-record, the correct ActiveOrient::Model-Class is instantiated.

```ruby
   ach = ActiveOrient::Query.new

   ach.queries << 'create class Contracts ABSTRACT'
   ach.queries << 'create property Contracts.subcategory link'
   ach.queries << 'create property Contracts.details link'
   ach.queries << 'create class Stocks extends Contracts'
   ach.queries << 'create class Futures extends Contracts'
   result = ach.execute_queries transaction: false
```

It queries the database as demonstrated above. In addition, the generated query itself is added to the »queries«-Stack and the result can be found in sample_query.records.

This feature can be used as a substitute for simple functions

```ruby
 roq = ActiveOrient::Query.new
 roq.queries =["select name, categories.subcategories.contracts from Industries where name containstext 'ial'"]
 roq.execute_queries.each{|x| puts x.name, x.categories.inspect }
 #--> Basic Materials 	[["#21:1"]]
 #--> Financial  	[["#21:2"]]
 #--> Industrial 	[["#23:0", "#23:1"]]
```

OrientDB supports the execution of SQL-Batch-Commands.
( http://orientdb.com/docs/2.0/orientdb.wiki/SQL-batch.html )
This is supported simply by using a Array as Argument for ActiveOrient::Query.queries

Therefor complex queries can be simplified using database-variables

```ruby
   ach = ActiveOrient::Query.new
   ach.queries << ["select expand( contracts ) from Openinterest"
	            "let con = select expand( contracts )  from Openinterest; ",
		    "...", ... ]
   result = ach.execute_queries
```

The contract-documents are accessible with

```ruby
  ORD.get_document '21:1'
  # --><Stocks: con_id: 77680640 currency: EUR details: #18:1 exchange: SMART local_symbol: BAS primary_exchange: IBIS subcategory: #14:1 symbol: BAS>
```
or

```ruby
  my_query = ActiveOrient::Query.new
  ['Contracts', 'Industries', 'Categories', 'Subcategories'].each do |table|
    my_query.queries = ["select count(*) from #{table}"]
    count = my_query.execute_queries
      # count => [#<ActiveOrient::Model::Myquery:0x00000003b317c8 @metadata={"type"=>"d", "class"=>nil, "version"=>0, "fieldTypes"=>"count=l"}, @attributes={"count"=>4 }] --> an Array with one Element, therefor count.pop
    puts "Table #{table} \t #{count.pop.count} Datasets "
  end
  #  -->Table Contracts 	 	56 Datasets
  #  -->Table Industries 	 8 Datasets
  #  -->Table Categories 	22 Datasets
  #  -->Table Subcategories 	35 Datasets
```

Note that the fetched Object is of type »Stocks« (ActiveOrient::Model::Stocks).

The OrientDB-API documentation can be found here: https://github.com/orientechnologies/orientdb-docs/wiki/OrientDB-ActiveOrient
and the ActiveModel-documentation is here: http://www.rubydoc.info/gems/activemodel
