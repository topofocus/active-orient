require 'awesome_print'
require_relative "../lib/active-orient.rb"

# Start server
ActiveOrient::OrientDB.default_server= { user: 'root', password: 'tretretre' }

# Select database
r = ActiveOrient::OrientDB.new database: 'NewTest'

# SELF <--- Class
# NO SELF <--- Object

doc1 = r.create_class "Document_Test"
ver1 = r.create_vertex_class "Vertex_Test"
a = doc1.create name: "Doc1"
v = ver1.create name: "Ver"

out = doc1.orientdb_class name: "Doc2345" # Used to instantiate an ActiveOrient Model
print "#{out} \n"

out = ver1.autoload_object "16:35" # Used to get a record by rid
print "#{out} \n"

print "#{ver1.superClass} \n" # Check superClass of the class

print "#{v.class} <--- \n"

print "#{doc1} <--- \n"

print "#{a} <--- \n"

print "#{v} <--- \n"

a = v.classname # Class of v
print "#{a} \n"

a = v.rid
print "#{a} \n" # RID of v

a = ver1.count where: {name: "Ver"}
print "#{a} \n"

print "1 #{v.to_human} \n" # Human version

print "2 #{v.content_attributes} \n" # Return attributes

print "3 #{v.default_attributes} \n" # Return created and updated

print "4 #{v.set_attribute_defaults} \n" # Set up

print "5 #{v.metadata} \n" # Set up
