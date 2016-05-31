########### FILE CREATE TO TEST EXPERIMENTAL FUNCIONS ###################à

require_relative "../lib/active-orient.rb"

ActiveOrient::OrientDB.default_server = { user: 'root', password: 'tretretre' }
r = ActiveOrient::OrientDB.new database: 'NewTest'

doc1 = r.open_class "DocumentTest" # Create Document/Vertex/Edge class
doc2 = r.open_class "DocumentArrive_Test"
doc1.create_property :familyname, type: :string
doc1.create_property :family, type: :linkset, other_class: "DocumentTest"

a1 = doc1.create name: "DocA", value: 34
a2 = doc1.create name: "DocB", value: 34
a3 = doc1.create name: "DocC", value: 34
a4 = doc1.create name: "DocD", value: 30
doc1.create name: "DocE", value: 30
doc1.create name: "DocF", value: 30

print "#{a1.ciao} \n"
a1.family = [a2, a3]
print "#{a1["family"].name} \n"
print "---> #{a1.family.class}\n"
# a1["family"] << a4
# print "#{a1.family.name} \n"


# ActiveOrient::OrientDB.methods.each do |m|
# print "#{m} \n"
# end
