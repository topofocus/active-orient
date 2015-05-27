# orientdb-rest
A simple ruiby wrapper for the REST-API of OrientDB


OrientDB is still under heavy development. Any non-java binary-API-binding is therefor subject of constant changes.

OrientDB provides a high-level REST-HTTP-API as well. This is most likely robust.

This small wrapper is written to send date gathered by a Ruby-programm easily into an OrientDB-Database.

It's initialized by

```ruby

```
 
 The provided datasetname is the working-database for all further operations.
 
 You can fetch a list of Classes by
 ``` ruby
 
 ```
 
 Creation and removal of Classes is straightforward
 ```ruby
 
 ```
 if a schema is used, Properties can retrieved, changed, added and removed
 ```ruby
 
 ```
 
 Documents can easily created, removed and queried
 ```ruby
 
 ```
 
 and off course - sql-commands can executed, singular or as batch.
 
 
 
 
 
 


