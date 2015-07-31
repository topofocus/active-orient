
require 'spec_helper'
require 'active_support'

module REST
  class Base
    def self.get_riid
      @@rid_store
    end
  end
end

describe REST::Model do
  before( :all ) do

    # working-database: hc_database
    REST::Base.logger = Logger.new('/dev/stdout')

    @r= REST::OrientDB.new database: 'hc_database' , :connect => false
    REST::Model.orientdb  =  @r
    @r.delete_class 'model_test'
    TestModel = @r.open_class "model_test" 
    @myedge = @r.create_edge_class  'Myedge'
    @mynode = @r.create_vertex_class  'Mynode'
  end

  context "REST::Model classes got a logger and a database-reference" do
    
    subject { REST::Model.orientdb_class name: 'Test' }
    it{ is_expected.to be_a Class }
    its( :logger) { is_expected.to be_a Logger }
    its( :orientdb) { is_expected.to be_a REST::OrientDB }

    it "a Model-Instance inherents logger and db-reference" do
      object =  subject.new
      expect( object.logger ).to be_a Logger
      expect( object.orientdb ).to be_a REST::OrientDB
    end

    it "repeatedly instantiated Model-Objects are allocated once" do
      second =  REST::Model.orientdb_class name: 'Test' 
      expect( second).to eq subject
    end
  end

  context "The Models have proper superClasses"  do
    it "A document class has an empty superClass" do
      expect( TestModel.superClass ).to eq "" 
    end
    it "An Vertex inherents from »V«" do
      expect( @mynode.superClass ).to eq "V"
    end
    it "An Edge inherents from »E«" do
      expect( @myedge.superClass ).to eq "E"
    end
  end

  context "Add a document to the class"  do
    it "the database is empty before we start" do
      @r.get_documents  TestModel
      expect( TestModel.count ).to be_zero
    end

    let( :new_document ){REST::Model::ModelTest.create test: 45 }
    it "create a document"  do
      expect( new_document.test ).to eq 45 
      expect(new_document).to be_a REST::Model::ModelTest
      expect( REST::Base.get_riid.values.detect{|x| x == new_document}).to be_truthy
    end  


    it "the document can be retrieved by all"  do
      all = TestModel.all
      expect(all).to be_a Array
      expect(all.size).to eq 1
      expect(all.first).to  be_a REST::Model::ModelTest
      expect(all.first.test).to eq 45
    end

    it "the document can be retrieved by first" do
      expect( TestModel.first ).to be_a REST::Model::ModelTest
      expect( TestModel.first.test ).to eq 45
    end

    it "the document can be updated"  do
      obj =  TestModel.create test: 77
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

    it "the document can be deleted"  do
      obj =  TestModel.first
      expect{ obj.delete }.to change { TestModel.count }.by -1
    end
  end

  context "ActiveRecord mimics"    do
   before(:all){ (0..45).each{|x| TestModel.create  test: x  }}
   it "fetch all documents into an Array" do
      all_documents = TestModel.all
      expect( all_documents ).to be_a Array #HashWithIndifferentAccess
      expect( all_documents ).to have_at_least(46).elements
      all_documents.each{|x| expect(x).to be_a REST::Model }
    end

    it "get a set of documents queried by where"  do
      all_documents = TestModel.all  ## all fetches only 20 records
#      puts all_documents.map( &:test).join(' .. ')
      nr_23=  TestModel.where  test: 23 
      expect( nr_23 ).to have(1).element
      expect( nr_23.first.test).to eq 23
      expect( TestModel.all.size).to eq  47
    end
    it "datasets are unique only  on update" do
    expect{ @r.update_or_create_documents( TestModel, :where => { test: 45 }) }. not_to change { TestModel.count }
     expect{ TestModel.create  test: 45 }.to change { TestModel.count }
    end


    it "creates an edge between two documents"  do
      node_1 =  @r.update_or_create_documents(  @mynode, :where => { test: 23 } ).first 
      node_2  =  @r.update_or_create_documents( @mynode, :where => { test: 15 } ).first 
      node_3 = @r.update_or_create_documents(  @mynode, :where => { test: 16 } ).first 
      the_edge= @myedge.create_edge( 
			  attributes: { halbwertzeit: 45 }, 
			  from: node_1,
			  to:   node_2  )
      expect( the_edge).to be_a REST::Model

      # creation of a second edge with the same properties leads to  reusing the existent edge
      the_edge2= @myedge.create_edge( 
			  attributes: { halbwertzeit: 45 }, 
			  from: node_1,
			  to:   node_2 , unique: true )
       expect( the_edge.link ).to eq the_edge.link
#      the_edge2= @myedge.create_edge( 
#			  attributes: { halbwertzeit: 46 }, 
#			  from: in_e,
#			  to:   in_e2  )
      expect( the_edge.out ).to eq node_1.link
      expect( the_edge.in ).to eq node_2.link
#      expect( the_edge2.out ).to eq in_e
#      expect( the_edge2.in ).to eq in_e2
      out_e =  @mynode.where(  test: 23  ).first 
      expect( out_e ).to eq node_1.link
      expect( out_e.attributes).to include 'out_Myedge'
      in_e = @mynode.where(  test: 15  ).first
#      puts "--------------------------------"
#      puts node_1.attributes.inspect
#      expect( in_e.attributes).to include 'in_Myedge'
 #    expect( node_1.myedge).to have(1).item
 #    expect( node_1.myedge[0][:out].test).to eq 23
 #    expect( node_1.in_Myedge[0][:in].test).to eq  15
    end

    it "deletes an edge"  do
      the_edges =  @myedge.all
      expect(the_edges.size).to  be >=1 

      the_edges.each do |edge|
	edge.delete
      end
      the_edges =  @myedge.all
      expect(the_edges.size).to  be_zero
    end

  end


end

