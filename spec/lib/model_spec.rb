
require 'spec_helper'
#require 'model_helper'
#require 'active_support'
 shared_examples_for 'basic class properties' do |bez|
     
     it "class #{bez}: initialize and add a property " do 
      ORD.delete_class bez 
      subject = ORD.create_class bez
puts "subject:  #{subject.inspect}"
puts "superclass: #{subject.superclass}"
puts "ref name: #{subject.ref_name}"
      subject.create_property :test_ind, type: 'string' 

      expect( subject.get_properties[:properties] ).to have(1).item 
     end
 end

module ActiveOrient
  class Base
    def self.get_riid
      @@rid_store
    end
  end
end

describe ActiveOrient::Model do
  before( :all ) do
#   ao =   ActiveOrient::OrientDB.new 
   ORD.delete_database database: ActiveOrient.database
   ORD =  ActiveOrient::OrientDB.new
   DB =  if RUBY_PLATFORM == 'java'
	   ActiveOrient::API.new
	 else
	   ORD
	 end
#    ORD = ActiveOrient::OrientDB.new database: 'ModelTest'
#    TestModel = ORD.open_class "Modeltest"
  #  ActiveOrient::Model::Modeltest.delete_class if defined? ActiveOrient::Model::Modeltest
    TestModel = ORD.create_class "Modeltest"
  end

  context "ActiveOrient::Model classes got a logger and a database-reference"  do

    subject { ActiveOrient::Model.orientdb_class name: 'Test' }
    it{ is_expected.to be_a Class }
    its( :logger) { is_expected.to be_a Logger }
    its( :orientdb) { is_expected.to be_a ActiveOrient::OrientDB }
    if RUBY_PLATFORM == 'java'
    its( :db) { is_expected.to be_a ActiveOrient::API }
    else
    its( :db) { is_expected.to be_a ActiveOrient::OrientDB }
    end

    it "a Model-Instance inherents logger and db-reference" do
      object =  subject.new
      expect( object.logger ).to be_a Logger
      expect( object.orientdb ).to be_a ActiveOrient::OrientDB
    end

    it "repeatedly instantiated Model-Objects are allocated once" do
      second =  ActiveOrient::Model.orientdb_class name: 'Test'
      expect( second).to eq subject
    end
  end  #context

  context "The Models have proper superClasses" do
    let (:base) { ORD.create_class( :my_class) }
    let (:node) { ORD.create_class( :my_node){ 'V' } }
    let (:edge) { ORD.create_class( :my_edge){ 'E' } }
    it "A document class has an empty superClass" do
      expect( base.superClass ).to eq  ActiveOrient::Model => nil
    end
    it "An Vertex inherents from »V«" do
      expect( node.superClass ).to eq  ActiveOrient::Model::V => 'V'
    end
    it "An Edge inherents from »E«" do
      expect( edge.superClass ).to eq ActiveOrient::Model::E => 'E'
    end
  end  # context

#  context "naming issues of classes"  do
#    ['Indextest','Testindex'].each do | this_class |
#      it_behaves_like 'basic class properties' , this_class
#    end
#  end
  context "add properties and indexes" , focus:true do

    let (:testIndex1) { ORD.create_class( :my_indexed_class_1) }
    let (:testIndex2) { ORD.create_class( :my_indexed_class_2) }
    let (:testIndex3) { ORD.create_class( :my_indexed_class_3) }
    let (:testIndex4) { ORD.create_class( :my_indexed_class_4) }
    it "create a single property"  do

      testIndex1.create_property( :Test, type: 'string' ) 

      expect( testIndex1.get_properties[:properties].size ).to eq 1
      expect( testIndex1.get_properties[:indexes]).to be_nil
    end
    it "create manualy properties and indices" do
      testIndex2.create_property( :Test, type: 'string' ) 
      ORD.create_index testIndex2, name: :testindex, on: :Test
      expect( testIndex2.get_properties[:indexes] ).to have(1).item
      ## this test fails if no index is preset before the condition ist fired.
      #  (get_properties is nil and size is not defined for nilclass.)
      expect { testIndex2.create_property( :Facility, type: 'integer' ) }.to change { testIndex2.get_properties[:properties].size }.by 1

      expect{ ORD.create_index testIndex2, name: :facilindex, on: :Facility }.to  change { testIndex2.get_properties[:indexes].size }.by 1
    end
# indices are definded on DB-Level and have to have unique names
    it "create a single property with a manual index" do
      testIndex3.create_property( :Test, type: 'string', index: {test_indes: :unique} )

      expect( testIndex3.get_properties[:properties] ).to have(1).item
      expect( testIndex3.get_properties[:indexes] ).to have(1).item
    end
    it "create several  properties with a composite index"  do
      ORD.create_class :industry
      count= testIndex4.create_properties(	 test:  {type: :integer},
					  symbol: { type: :string },
					  industries: { type: 'LINKMAP', linked_class: 'Industry' }   ) do
					    { sumindex: :unique }
					  end
      expect( count ).to eq 3  # three properties
      expect( testIndex4.get_properties[:properties] ).to have(3).items
      expect( testIndex4.get_properties[:indexes] ).to have(1).item
      expect{ ORD.create_index testIndex4, name: :facil4index, on: :symbol }.to  change { testIndex4.get_properties[:indexes].size }.by 1
    end
  end   ## properties 

  context "Add and modify documents"  do
    before( :all ) do
      ActiveOrient::Model::Documenttest.delete_class if ActiveOrient.database_classes.include?( 'Documenttest')
      Doc_class = ORD.open_class "Documenttest"

    end
    it "put some data into the class"  do

      (0..45).each{|x|  Doc_class.create  test_cont: x  }
      expect( Doc_class.count ).to eq 46
    end

    it "the database is empty before we start"  do
      expect( TestModel.all ).to be_empty
      expect( ORD.get_documents  from: TestModel ).to be_empty
      expect( TestModel.count ).to be_zero
    end

    let( :new_document ){TestModel.create test: 45 }
    it "create a document"  do
      expect( new_document.test ).to eq 45
      puts new_document.inspect
      expect(new_document).to be_a ActiveOrient::Model::Modeltest
      expect( ActiveOrient::Base.get_riid.values.detect{|x| x == new_document}).to be_truthy
    end


    it "the document can be retrieved by all"  do
      all = TestModel.all
      expect(all).to be_a Array
      expect(all.size).to eq 1
      expect(all.first).to  be_a ActiveOrient::Model::Modeltest
      expect(all.first.test).to eq 45
    end

    it "the document can be retrieved by first" do
      expect( TestModel.first ).to be_a ActiveOrient::Model::Modeltest
      expect( TestModel.first.test ).to eq 45
    end
##### Method Missing [:to_ary] ---> Dokumente werden wahrscheinlich aus dem Cash genommen
    #und nicht von dr Datenbank abgefragt
    it "the document can be updated"   do
      obj =  TestModel.create test: 77
      puts obj.inspect
      expect{ obj.update set: { test: 76, new_entry: "This is a new Entry" } }.to change{ obj.version }.by 1
      expect( obj.test ).to eq 76
      expect( obj.new_entry).to be_a String
    end

    it "various Properties can be added to the document" do
      obj =  TestModel.first
      obj.update set: { a_array: aa= [ 1,4,'r', :r ]  , a_hash: { :a => 'b', b: 2 } }
      expect( obj.a_array ).to eq aa
      expect{ obj.reload! }.not_to change{ obj.attributes }
    end

    it "a value can be added to the array" do
      obj =  TestModel.first
      obj.add_item_to_property 'a_array', 56
      expect(obj.a_array).to eq [ 1,4,'r', 'r', 56 ]

    end

    it "the document can be deleted"  do
      obj =  TestModel.first
      expect{ obj.delete }.to change { TestModel.count }.by -1
    end
  end #context

  context "ActiveRecord mimics"   do
    before(:all) do 
	  ORD.delete_class 'E'
          MyEdge = ORD.create_edge_class  'Myedge'
	  MyNode = ORD.create_vertex_class  'Mynode'
	  (0..45).each{|x| TestModel.create  test: x  }
	  DB.get_database_classes requery:true
    end
    it "fetch all documents into an Array" do
      all_documents = TestModel.all
      expect( all_documents ).to be_a Array #HashWithIndifferentAccess
      expect( all_documents ).to have_at_least(45).elements
      all_documents.each{|x| expect(x).to be_a ActiveOrient::Model }
    end

    it "get a set of documents queried by where"   do
      nr_23=  TestModel.where  test: 23
      expect( nr_23 ).to have(1).element
      expect( nr_23.first.test).to eq 23
    end
    it "datasets are unique only  on update" do
      expect{ TestModel.update_or_create(  :where => { test: 45 }) }. not_to change { TestModel.count }
      expect{ TestModel.create  test: 45 }.to change { TestModel.count }
    end


    it "creates an edge between two documents"  do
      node_1 =  TestModel.where( test: 45 ).first
      node_2 =  TestModel.where( test: 2 ).first
      node_3 = TestModel.where( test: 16 ).first
      the_edge= ActiveOrient::Model::E.create_edge( attributes: { halbwertzeit: 655 },
					  from: node_1,
					    to: node_2  )
      expect( the_edge ).to be_a ActiveOrient::Model
      expect( the_edge.in ).to eq node_2
      expect( the_edge.out ).to eq node_1

      # creation of a second edge with the same properties leads to  reusing the existent edge
      the_edge2= ActiveOrient::Model::E.create_edge(
		    attributes: { halbwertzeit: 655 },
		    from: node_1,
		    to:   node_2 , unique: true )
      expect( the_edge.rid ).to eq the_edge2.rid
      #      the_edge2= @myedge.create_edge(
      #			  attributes: { halbwertzeit: 46 },
      #			  from: in_e,
      #			  to:   in_e2  )
      expect( the_edge.out ).to eq node_1 ## hier wird ein Document zurück gegeben...
      expect( the_edge.in ).to eq node_2
      #      expect( the_edge2.out ).to eq in_e
      #      expect( the_edge2.in ).to eq in_e2
#      out_e =  TestModel.where(  test: 23  ).first
#      expect( out_e ).to eq node_1
#      expect( out_e.attributes).to include 'out_Myedge'
#      in_e = TestModel.where(  test: 15  ).first
      #      puts "--------------------------------"
      #      puts node_1.attributes.inspect
      #      expect( in_e.attributes).to include 'in_Myedge'
      #    expect( node_1.myedge).to have(1).item
      #    expect( node_1.myedge[0][:out].test).to eq 23
      #    expect( node_1.in_Myedge[0][:in].test).to eq  15
    end

    it "deletes an edge"  do
      the_edges =  ActiveOrient::Model::E.all
      expect(the_edges.size).to  be >=1

      the_edges.each do |edge|
        edge.delete
      end
      the_edges =  ActiveOrient::Model::E.all
      expect(the_edges.size).to  be_zero
    end
#
  end

end
