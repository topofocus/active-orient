require 'awesome_print'
require_relative "../lib/active-orient.rb"

# Start server
ActiveOrient::OrientDB.default_server= { user: 'root', password: 'tretretre' }

# Select database
r = ActiveOrient::OrientDB.new database: 'NewTest'

#r.delete_class "Document_Test"
doc1 = r.create_class "DocumentTest" # Create Document/Vertex/Edge class
doc2 = r.create_class "DocumentArrive_Test"
ver1 = r.create_vertex_class "VertexTest"
ver2 = r.create_vertex_class "VertexArriveTest"
edg1 = r.create_edge_class "EdgeTest"
ver1 = r.open_class "VertexTest" # Same as create_class

par = r.get_documents from: "DocumentTest", where: {name: "Doc1"} # Get documents
par = doc1.get_documents where: {name: "Doc1"} # Same as above
print "0 "
ap par, :indent => -2

num = r.count_documents from: "DocumentTest", where: {name: "Doc1"}
num2 = doc1.count where: {name: "Doc1"}
print "\n1 COUNT: #{num2} \n\n"

r.create_or_update_document doc1, set: {familyname: "John"}, where: {name: "Doc1"}
r.update_or_create_documents doc1, where: {name: "Doc1"}, set: {age: 91}
doc1.update_or_create_documents where: {name: "Doc1"}, set: {age: 91}
doc1.update_or_create_documents where: {name: "Doc2"}, set: {age: 91}
par = doc1.get_documents where: {name: "Doc1"}
#ap par, :indent => -2

print "2 #{par[0].attributes} \n\n" # Access attributes
print "3 #{par[0].metadata} \n\n" # Access metadata

r.delete_documents doc1, where: {name: "Doc2"}
doc1.delete_documents where: {name: "Doc2"}

a = r.get_document "1:0" # Get by RID

r.patch_document "1:0" do {name: "is a test"} end

r.update_documents doc1, set: {age: 191}, where: {name: "Doc1"} # Update a document
doc1.update_documents set: {age: 191}, where: {name: "Doc1"}

a = r.execute "Document_Test" do # To execute commands
  [{type: "cmd", language: 'sql', command: "SELECT * FROM DocumentTest WHERE name = 'Doc1'"}]
end
print "\n4 #{a} \n \n"

a = r.classname doc1
a = doc1.classname
print "5 #{a} \n \n"
