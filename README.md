# ActiveOrient
Use OrientDB to persistently store dynamic Ruby-Objects and use database queries to manage even very large
datasets.

#### Other Documents
- [Experiments with Joins / Linkmaps ](./linkmap.md)

- [Experiments with the GratefulDeadConcerts Sample Database](./gratefuldeadconcerts.md)

- [Namespace Support](./namespace.md)

- [TimeGraph Implementation](examples/time_graph.md)

- [Rails 5-Integration](./rails.md)

You need a ruby 2.3, 2.4  or a jruby 9.1x Installation and a working OrientDB-Instance (Version 2.2 prefered).
The jruby-part is experimental.

### Quick Start

 - clone the project, 
 - run bundle install & bundle update, 
 - update config/connect.yml, 
 - create the documentation by calling »rdoc«
 - start an irb-session by calling  
```
cd bin
./active-orient-console test   # or d)develpoment, p)roduction environment as defined in config/connect.yml
```

«ORD» or «DB» is the Database-Instance itself. If the Database noticed is not present, it is created on startup.
A simple SQL-Query is submitted by providing a Block to »execute«
 ```ruby
 result =  ORD.execute { "select * from Stock" } 
 ```
Obviously, the class »Stock« has to exist. 
Let's create some classes

 ```ruby
    ORD.create_class        'ClassDocumentName'  # creates or opens a basic document-class
    ORD.create_vertex_class 'ClassVertexName'  # creates or opens a vertex-class
    ORD.create_edge_class   'ClassEdgeName'  # creates or opens an edge-class, providing bidirectional links between documents
    {Classname}.delete_class			 # removes the class in the database and destroys the ruby-object
 ```

Classnames appear unchanged as Database-Classes. Strings and Symbols are accepted. Depending on the namespace choosen in 'config/config.yml' Model-Classes are allocated and linked to database-classes. For simplicity, here we omit any namespace ( :namespace: :object in config.yml). Thus the Model-Obects are accessible directly.


**Naming-Convention:** The name given in the »create-class«-Statement becomes the Database-Classname. 
In Ruby-Space its Camelized, ie:  ORD.create_class(:hut_ab) generates a Ruby-Class »HutAb«. 

This can be customized in the "naming_convention"-class-method, which has to be defined in 'config/boot.rb'. The naming_convention changes the ruby-view to the classes. The Database-Class-Name is derived from the argument to #CreateClass, ORD.create_class('HANDS_UP') creates a database-class "HANDS_UP' and a Ruby-Class "HandsUp".

ActiveOrient::Model's can be customized through methods defined in the model-directory. These methods are
loaded automatically afert executing #CreateClass (and through the preallocation process). Further details in the Examples-Section.

#### CRUD
The CRUD-Process (create, read = query, update and remove) is performed as
```ruby	
    ORD.create_class :M
    M.create name: 'Hugo', age: 46, interests: [ 'swimming', 'biking', 'reading' ]
    # or
    new_record =  M.new  age: 46, interests: [ 'swimming', 'biking', 'reading' ]
    new_record.save   # alternative: new_record.update
    ##
    hugo = M.where( name: 'Hugo' ).first
    hugo.update set: { :father => M.create( name: "Volker", age: 76 ) } # we create an internal link
    hugo.father.name	# --> volker
    M.remove hugo 
    M.delete_class	# removes the class from OrientDB and deletes the ruby-object-definition
 ```
 
#### Inherence

Create a Tree of Objects with create_classes
```ruby
  ORD.create_classes  sector: [ :industry, :category, :subcategory ] 
  => {Sector=>[Industry, Category, Subcategory]}
  Industry.create name: 'Communications'   #--->   Create an Industry-Record with the attribute "name"
  Sector.where  name: 'Communications'	   #--->   an Array with the Industry-Object
  => [#<Industry:0x0000000225e098 @metadata= (...) ] 
 ```
 ***notice*** to create inherent Vertices use ORD.create_classes( sector: [ :industry, :category, :subcategory ]){ :V  } 

#### Preallocation of Model-Classes
All database-classes are preallocated after connecting to the database. Thus you can use Model-Classes from the start.

If the "rid" is known, any Object can be retrieved and correctly allocated by
```ruby
  the_object =  V.autoload_object "xx:yy" # or "#xx:yy"
  --->  {ActiveOrient::Model} Object 
```
The database-class  «V» is present in any case. Any model-class can be used, even the parent »ActiveOrient::Model«

#### Properties
The schemaless mode has many limitations. ActiveOrient offers a Ruby way to define Properties and Indexes

 ```ruby
 ORD.create_class  :M, :item
 M.create_property :symbol 			# the default-case: type: :string, no index
 M.create_property :con_id,   type: :integer
 M.create_property :details,  type: :link, other_class: 'Contracts'
 M.create_property :items,    type: :linklist, :linklist: Item
 M.create_property :name,    index: :unique	# or  M.create_property( 'name' ){ :unique }
 ```

(Experimental) You can put restrictions on your properties with the command "alter_property":

```ruby
  M.alter_property property: "value", attribute: "MIN", alteration: 0
  M.alter_property property: "value", attribute: "MAX", alteration: 23
```

#### Active Model interface

As for ActiveRecord-Tables, the Model-class itself provides methods to inspect and filter datasets form the database.

```ruby
  M.all   
  M.first
  M.last  	# notice: last does not work in orientdb version 2.2, because the sorting algorithm for rid's is damaged
  M.all.last    # or M.where( ... ).last  walkaround for  Orientdb V 2.2
  M.where town: 'Berlin'

  M.count where: { town: 'Berlin' }
```
»count« gets the number of datasets fulfilling the search-criteria. Any parameter defining a valid SQL-Query in Orientdb can be provided to the »count«, »where«, »first« and »last«-method.

A »normal« Query is submitted via
```ruby
  M.get_records projection: { projection-parameter },
		  distinct: { some parameters },
		  where: { where-parameter },
		  order: { sorting-parameters },
		  group_by: { one grouping-parameter},
		  unwind:  ,
		  skip:    ,
		  limit:  

#  or
 query = OrientSupport::OrientQuery.new {paramter}  
 M.query_database query

```

To update several records, a class-method »update_all« is defined.
```ruby
  M.update_all connected: false   	# add a property »connected» to each record
  M.update_all set:{ connected: true },  where: "symbol containsText 'S'" 
```

Graph-support:

```ruby
  ORD.create_vertex_class :the_vertex
  ORD.create_edge_class :the_edge
  vertex_1 = TheVertex.create  color: "blue"
  vertex_2 = TheVertex.create  flower: "rose"
  TheEdge.create_edge attributes: {:birthday => Date.today }, from: vertex_1, to: vertex_2
```
It connects the vertexes and assigns the attributes to the edge.

To query a graph,  SQL-like-Queries and Match-statements can be used (see below). 


#### Links and LinkLists

A record in a database-class is defined by a »rid«. If this is stored in a class, a link is set.
In OrientDB links are used to realize unidirectional 1:1 and 1:n relationships.

ActiveOrient autoloads Model-objects when they are accessed. Example:
If an Object is stored in Cluster 30 and id 2, then "#30:2" fully qualifies the ActiveOrient::Model object and sets the 
link if stored somewhere.

```ruby
  ORD.create_class 'test_link'
  ORD.create_class 'test_base'

  link_document =  TestLink.create  att: 'one attribute'
  base_document =  TestBase.create  base: 'my_base', single_link: link_document
```
base_document.single_link just contains the rid. When accessed, the ActiveOrient::Model::Testlinkclass-object is autoloaded and

``` ruby
   base_document.single_link.att
```
reads the stored content of link_document.

To store a list of links to other Database-Objects, a simple Array is allocated
``` ruby
  # predefined linkmap-properties
  TestLink.create_property  :links,  type: :linklist, linkedClass: :test_links 
  base_document =  TestBase.create links: []  
  (0 .. 20).each{|y| base_document.links << TestLink.create( nr: y )}
  
  #or in schemaless-mode
  base_document = TestBase.create links: (0..20).map{|y| TestLink.create nr: y}
  base_document.update
```
base_document.links behaves like a ruby-array.

If you got an undirectional graph

   a --> b ---> c --> d

the graph elements can be explored by joining the objects (a[6].b[5].c[9].d)

Refer to the "Time-Graph"-Example for an Implementation of an bidirectional Graph with the same Interface

#### Edges
Edges provide bidirectional Links. They are easily handled
```ruby
  ORD.create_vertex_class :the_vertex 	# -->  TheVertex
  ORD.create_edge_class  :the_edge      # -->  TheEdge

  start = TheVertex.create something: 'nice'
  the_end  = TheVertex.create something: 'not_nice'
  the_edge = TheEdge.create attributes: {transform_to: 'very bad'},
			       from: start,
			       to: the_end
```
Edges are connected to vertices by »in« and »out«-Methods.
Inherence is supported.

i.e.
```ruby
  ORD.create_class( top_edge ) { THE_EDGE }
  ORD.create_class( on_top_edge ) { TOP_EDGE }

  ON_TOP_Edge.create  from: start, to: the_end
  start.reload!
  start.out :the_edge 
  => [#<TOP_EDGE:0x00000001d92f28 @metadata= ... ]
```

Edge-links are displayed and retrieved by
```ruby
  start.edges	  # :in | :out | :all 
   => ["#73:0"] 
  
  start.edges(:out).map &:from_orient
  => [#<TOP_EDGE:0x00000001d92f28 @metadata= ... ]

```


The create-Method od Edge-Classes takes a block. Then all statements are transmitted in batch-mode.
Assume, Vertex1 and Vertex2 are Vertex-Classes and TheEdge is an Edge-Class, then
```ruby
  record1 = (1 .. 100).map{|y| Vertex1.create testentry: y  }
  record2 = (:a .. :z).map{|y| Vertex2.create testentry: y  }
  edges = TheEdge.create attributes: { study: 'Experiment1'} do  | attributes |
   # map returns an array, which is further processed by #create_edge 
    ('a'.ord .. 'z'.ord).map do |o| 
	  { from: record1.find{|x| x.testentry == o },
	    to:  record2.find{ |x| x.testentry.ord == o },
	    attributes: attributes.merge( key: o.chr ) }
      end  
```
connects the vertices and provides a variable "key" and a common "study" attribute to each edge.


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
  q.let << {a: OQ.new( from: '#5:0' ) }
  q.let << {b: OQ.new( from: '#5:1' ) }
  q.let << '$c= UNIONALL($a,$b) '
  q.projection << 'expand( $c )'
  q.to_s  # => select expand( $c ) let $a = ( select from #5:0 ), $b = ( select from #5:1 ), $c= UNIONALL($a,$b)
```

or

```ruby
  last_12_open_interest_records = OQ.new from: OpenInterest, 
					order: { fetch_date: :desc } , limit: 12
  bunch_of_contracts = OQ.new from: last_12_open_interest_records, 
			      projection: 'expand( contracts )'
  distinct_contracts = OQ.new from: bunch_of_contracts, 
			      projection: 'expand( distinct(@rid) )'

  distinct_contracts.to_s
   => "select expand( distinct(@rid) ) from ( select expand( contracts ) from ( select  from open_interest order by fetch_date desc limit 12 ) ) "

  cq = ORD.get_documents query: distinct_contracts
```
this executes the query and returns the adressed rid's, which are eventually retrieved from the rid-cache.
#### Match

A Match-Query starts at the given ActiveOrient::Model-Class. The where-cause narrows the sample to certain 
records. In the simplest version this can be returned:
  
```ruby
  ORD.create_class :Industry
  Industry.match where:{ name: "Communications" }
  => #<Query:0x00000004309608 @metadata={"type"=>"d", "class"=>nil, "version"=>0, "fieldTypes"=>"Industries=x"}, @attributes={"Industries"=>"#21:1", (...)}>
```

The attributes are the return-Values of the Match-Query. Unless otherwise noted, the pluralized Model-Classname is used as attribute in the result-set. *Note* that the Match statement returns a »Query«-record. Its up to the usere, to transform the attributes to Model-Objects. This is done by the »to_orient« directive, ie. »xx.Industries.to_orient «

```ruby
  Industry.match where name: "Communications" 
  ## is equal to
  Industry.match( where: { name: 'Communications' }).first.Industries
```
The Match-Query uses this result-set as start for subsequent queries on connected records.
If a linear graph: Industry <- Category <- Subcategory <- Stock  is build, Subcategories can 
accessed starting at Industry defining

```ruby
  var = Industry.match( where: { name: 'Communications'}) do | query |
    query.connect :in, count: 2, as: 'Subcategories'
    puts query.to_s  # print the query prior sending it to the database
    query            # important: block has to return the query 
  end
  => MATCH {class: Industry, as: Industries} <-- {} <-- { as: Subcategories }  RETURN Industries, Subcategories
```

The result-set has two attributes: Industries and Subcategories, pointing to the filtered datasets.

By using subsequent »connect« and »statement« method-calls even complex Match-Queries can be constructed. 


#### Other Documents
- [Experiments with Joins / Linkmaps ](./linkmap.md)

- [Experiment with the GratefulDeadConcerts Sample Database](./gratefuldeadconcerts.md)

- [Namespace Support](./namespace.md)

- [TimeGraph Implementation](examples/time_graph.md)


  deactivated behavior: to turn it on, some work on base.rb is required
``` 
  start.the_edge  # --> Array of "TheEdge"-instances connected to the vertex
  start.the_edge.where transform_to: 'good'     # ->  empty array
  start.the_edge.where transform_to: 'very bad' #-->  previously connectd edge
  start.something     # 'nice'
  end.something	      # 'not_nice'
  start.the_edge.where( transform_to: 'very bad').in.something  # => ["not_nice"] 
  (...)
  the_edge.delete # To delete the edge
```
