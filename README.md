# ActiveOrient
Use OrientDB to persistently store Ruby-Objects and use database queries to manage even very large datasets.   
**OrientDB Version 3 is required**,  OrientDB 3.1 is supported

---
**Status**

* Preparing for a gem release in Dec. 2020

* Recent updates: concurrent database queries, multiple model-dirs, match-statements

---
### Quick Start

You need a ruby 2.6 / 2.7  Installation and a working OrientDB-Instance (Version 3.0.17 or above).

- clone the project, 
 - run bundle install ; bundle update, 
 - update config/connect.yml,
 - create the documentation:
 ```
   sdoc . -w2 -x spec -x example
   ```
   and point the browser to ~/active-orient/doc/index.htm
   
-  read the [Wiki](./../../wiki/Initialisation)
 - and start an irb-session by calling  
```
cd bin
./active-orient-console t)est   # or d)develpoment, p)roduction environment as defined in config/connect.ym
```

### Philosophy


OrientDB is a Multi-Model-Database. It shares the concept of Inheritance with OO-Languages, like Ruby. 
 
Upon initialization `ActiveOrient` reads the complete structure of the database, creates corresponding ruby-classes (including inheritance) and then loads user defined methods from the `Model Directory`. A separate schema definition is not neccesary. 

`ActiveOrient` queries the OrientDB-Database, provides a cache to speed things up and provides handy methods to simplify the work with OrientDB. Like Active-Record it represents the "M" Part of the MCV-Design-Pattern. There is explicit Namespace support. Its philosophie resembles the [Hanami Project](https://github.com/hanami/hanami). 




#### CRUD
The CRUD-Process (create, read = query, update and remove) is performed as
```ruby	
    # create the class
    V.create_class :m   # V is the base »vertex» class. M is a vertex-class.
    # create a record
    M.create name: 'Hugo', age: 46, interests: [ 'swimming', 'biking', 'reading' ]
    # query the database
    hugo = M.where( name: 'Hugo' ).first
    # update the dataset
    hugo.update father: M.create( name: "Volker", age: 76 )  # we create an internal link
    hugo.father.name	# --> volker
    # change array elements
    hugo.interests << "dancing"  # --> [ 'swimming', 'biking', 'reading', 'dancing' ]
    M.remove hugo 
    M.delete_class	# removes the class from OrientDB and deletes the ruby-object-definition
 ```
 

#### Active Model interface

As for ActiveRecord-Tables, the Model-class itself provides methods to inspect and filter datasets form the database.

```ruby
  M.all   
  M.first
  M.last
  M.where town: 'Berlin'
  M.like "name =  G*"

  M.count where: { town: 'Berlin' }
```
»count« gets the number of datasets fulfilling the search-criteria. Any parameter defining a valid SQL-Query in Orientdb can be provided to the »count«, »where«, »first« and »last«-method.

A »normal« Query is submitted via
```ruby
  M.query.projection( projection-parameter)
	  .distinct( some parameters)
	  .where( where-parameter)
	  .order( sorting-parameters )
	  .group_by( one grouping-parameter )
	  (...)
	 .execute

```

To update several records, a class-method »update« is provided.
```ruby
  M.update connected: false   	# add a property »connected» to each record
  M.update set:{ connected: true },  where: "symbol containsText 'S'" 
```

Graph-support:

```ruby
  V.create_class :the_vertex
  E.create_class :the_edge
  vertex_1 = TheVertex.create  color: "blue"
  vertex_2 = TheVertex.create  flower: "rose"
  vertex_1.assign via: TheEdge, vertex: vertex_2, attributes: {:birthday => Date.today }
```
It connects the vertices and assigns the attributes to the edge.

To query a graph,  SQL-like-Queries and Match-statements can be used (details in the [wiki](https://github.com/topofocus/active-orient/wiki)). 

#### Other Documents

- [Rails 5-Integration](./rails.md)


