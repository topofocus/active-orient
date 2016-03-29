require 'awesome_print'
require_relative "../lib/active-orient.rb"

# Start server
ActiveOrient::OrientDB.default_server= { user: 'root', password: 'tretretre' }

# Select database
r = ActiveOrient::OrientDB.new database: 'NewTest'

doc1 = r.create_class "DocumentTest"
ver1 = r.create_vertex_class "VertexTest"
a = doc1.create name: "Doc1"
v = ver1.create name: "Ver"

out = doc1.orientdb_class name: "Doc2345" # Used to instantiate an ActiveOrient Model
print "1 #{out} \n"

out = ver1.autoload_object "16:35" # Used to get a record by rid
print "2 #{out} \n"

print "3 #{ver1.superClass} \n" # Check superClass of the class

print "4 #{v.class} \n"

print "5 #{doc1}  \n"

print "6 #{a}  \n"

print "7 #{v}  \n"

a = v.classname # Class of v
print "8 #{a} \n"

a = v.rid
print "9 #{a} \n" # RID of v

a = ver1.count where: {name: "Ver"}
print "10 #{a} \n"

print "11 #{v.to_human} \n" # Human version

print "12 #{v.content_attributes} \n" # Return attributes

print "13 #{v.default_attributes} \n" # Return created and updated

print "14 #{v.set_attribute_defaults} \n" # Set up

print "15 #{v.metadata} \n" # Set up
