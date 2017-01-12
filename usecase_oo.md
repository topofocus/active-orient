## Usecase
Below some typical features are summarized by example

Initialize ActiveOrient by calling »bin/active-orient-console t«.
This connects to the Test-Database.

 ```ruby
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
ORD.create_classes( [ :a, :b, :c ] ){ :V } 
```
creates them with a single statement. They are mapped to Ruby-classes "A","B" and "C". 

#### Object Mapping
Lets create a class, put some content in it and perform basic oo-steps.

Attributes(Properties) do not have to be formaly declared. One can save any Object, which
provides a 'to_orient' method. Base-Classes are supported out of the box.
»update«  

``` ruby
  ORD.create_class 'my_a_class'
  => MyAClass
  my_class = MyAClass.create test: 45
  my_class.update set: { a_array: aa= [ 1,4,'r' ]  , 
                  a_hash: { :a => 'b', b: 2 } }
  my_class.to_human
  => "<MyAClass: a_array: [1, 4, r], a_hash: { a => b , b =>2}, test: 45>" 

```
**Notice** Ruby-Symbols are converted to Strings and masked as ":{symbol}:".
There is a method: String#from_orient, which reverses the prodedure.

Attibutes/properties of the Database-Record  can be handled as normal ruby objects ie.
 
``` ruby
  my_class.a_array << "a new element"
  my_class.a_hash[ :a_new_element ] =  "value of the new element"
  my_class.test += 3
  my_class.test =  567
  my_class.update
```

## Inherence

( to be continued )
