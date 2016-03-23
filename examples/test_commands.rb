require 'awesome_print'
require_relative "../lib/active-orient.rb"

# Start server
ActiveOrient::OrientDB.default_server = { user: 'root', password: 'tretretre' }

# Select database
r = ActiveOrient::OrientDB.new database: 'NewTest'

print "\n"+"*"*20+"DATABASE"+"*"*20+"\n"

print "#{r.get_resource} \n" # <--- See the address of the server
print "#{r.get_databases} \n" # <--- List available databases

# r.create_database(database: "Onetwothree") # <--- Create a new database
print "#{r.database} \n" # <--- See the working database

# r.delete_database database: "Onetwothree" # <--- Delete an old database

print "\n"+"*"*20+"CLASSES"+"*"*20+"\n"

ap r.get_classes, :indent => -2 # <--- See available classes
print "#{r.get_classes 'name'} \n" # <--- See the names of the available classes

print "#{r.class_hierarchy} \n" # <--- See hierarchy of the classes
print "#{r.class_hierarchy base_class: 'V'} \n" # <--- See hierarchy under V (Vectors classes)
print "#{r.class_hierarchy base_class: 'E'} \n" # <--- See hierarchy under E (Edges classes)

print "#{r.database_classes} \n" # See classes without including System classes
print "#{r.database_classes include_system_classes: true} \n " # See classes including System classes
print "#{r.inspect_classes} \n" # Same as r.database_classes



doc1 = r.create_class "DocumentTest" # Create Document/Vertex/Edge class
doc2 = r.create_class "DocumentArriveTest"
ver1 = r.create_vertex_class "VertexTest"
ver2 = r.create_vertex_class "Vertex_ArriveTest"
edg1 = r.create_edge_class "EdgeTest"
ver1 = r.open_class "VertexTest" # Same as create_class

print "\n"+"*"*20+"RECORDS"+"*"*20+"\n"

a = doc1.create name: "Doc1"
a2 = doc1.create name: "Doc12"
b = doc2.create name: "Doc2"
b2 = doc2.create name: "Doc22"
 aver = ver1.create vname: "Ver1"
 aver2 = ver1.create vname: "Ver12"
 bver = ver2.create vname: "Ver2"
 bver2 = ver2.create vname: "Ver22"

edg1.create_edge attributes: {famname: "edg1"}, from: aver, to: [bver, bver2], unique: true
nex = edg1.create_edge attributes: {familyname: "edg2"}, from: aver, to: [bver, bver2], unique: true # <--- We don't overwrite since we select a unique
nex1 = edg1.create_edge attributes: {familyname: "edg3"}, from: aver, to: [bver, bver2]
nex2 = edg1.create_edge attributes: {familyname: "edg4"}, from: aver, to: [bver, bver2]

print "#{nex1}"
print "\n\n BVER = #{bver.rid} \n" # Check the RID of the vertex
r.delete_edge nex1, nex2 # Used to delete edges
r.delete_class doc2 # Used to delete a class
doc2 = r.create_class "Document_Arrive_Test"

print "\n"+"*"*20+"PROPERTY"+"*"*20+"\n"

r.create_property doc2, :name, type: :string, index: :string #add one property
doc2.create_property :familyname, type: :string, index: :string #the same but starting directly from the class
r.create_properties doc2, {age: {type: :integer}, address: {type: :string}} #add more properties
doc2.create_properties({feetsize: {type: :integer}, country: {type: :string}})
b = doc2.create name: "Lucas", age: 91 #add more properties directly from the class

print "\n"+"*"*20+"\n"
r.delete_property doc2, "age" #delete one property
doc2.delete_property "country" #delete one property directly from the class
print "\n"+"*"*20+"\n"

ap r.get_class_properties doc2 #get the properties of a class
ap doc2.get_class_properties #get the properties of a class directly from the class

print "\n"+"*"*20+"\n"

r.print_class_properties doc2 #get the properties of a class in nice way
doc2.print_class_properties #get the properties of a class in nice way directly from the class

gg = r.create_document doc2, attributes: {name: "Test"}
hh = doc2.create_document attributes: {name: "Code"}

r.delete_document gg, hh # delete a document from database
doc2.delete_document hh # delete a document from a class

r.create_index doc2, name: "name" #Create index
