
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
    @r.delete_class 'modeltest'
    @testmodel = @r.create_class "modeltest" 
    @myedge = @r.create_edge_class name: 'Myedge'
    @mynode = @r.create_vertex_class name: 'Mynode'
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
      expect( @testmodel.superClass ).to eq "" 
    end
    it "An Vertex inherents from »V«" do
      expect( @mynode.superClass ).to eq "V"
    end
    it "An Edge inherents from »E«" do
      expect( @myedge.superClass ).to eq "E"
    end
  end

  context "Add a document to the class" do
    it "the database is empty before we start" do
      @r.get_documents o_class: @testmodel
      expect( @testmodel.count ).to be_zero
    end

    let( :new_document ){REST::Model::Modeltest.new_document attributes: { test: 45} }
    it "create a document" do
      before   =  @testmodel.count 
      expect( new_document.test ).to eq 45 # = @testmodel.new_document attributes: { test: 45} 
      after = @testmodel.count   
      expect( before +1 ).to eq after
      expect(new_document).to be_a REST::Model::Modeltest
      expect( REST::Base.get_riid.values.detect{|x| x == new_document}).to be_truthy
    end  


    it "the document can be retrieved by all"  do
      all = @testmodel.all
      expect(all).to be_a Array
      expect(all.size).to eq 1
      expect(all.first).to  be_a REST::Model::Modeltest
      expect(all.first.test).to eq 45
    end

    it "the document can be updated"  do
      obj =  @testmodel.first
      expect{ obj.update set: { test: 76, new_entry: "This is a new Entry" } }.to change{ obj.version }.by 1
      expect( obj.test ).to eq 76
      expect( obj.new_entry).to be_a String
    end

    it "the document can be deleted"  do
      obj =  @testmodel.all.first
      obj.delete
      expect( @testmodel.all ).to be_empty
    end
  end
  context  "Links and Linksets are followed"  do
    before(:all) do 
      @r.delete_class  'Testlinkclass'
      @r.delete_class  'Testbaseclass'

      @link_class = @r.create_class 'Testlinkclass'
      @base_class = @r.create_class 'Testbaseclass'
      @base_class.create_property field: 'to_link_class', type: 'link', linked_class: @link_class
      @base_class.create_property field: 'a_link_set', type: 'linkset', linked_class: @link_class
    
    end
     let( :base_document) { @base_class.new_document attributes: { base: 'my_base_with_linkset' } }

    it "create a link"   do
     link_document =  @link_class.new_document attributes: { att: 'one attribute' } 
     base_document =  @base_class.new_document attributes: { base: 'my_base', to_link_class: link_document.link } 
     expect(base_document.to_link_class).to eq link_document
    end

    it "create a linkset" do
      link_document =  @link_class.new_document attributes: { att: " -1 attribute" } 
      base_document.update_linkset( :a_link_set, link_document )
      expect( base_document.a_link_set ).to have(1).item
      expect( base_document.a_link_set.first).to be_a REST::Model
    end

    it "create multible links into a linkset " do
    base_document.update_linkset(:a_link_set) do 
      (1..9).map do |x|
	link_document =  @link_class.new_document attributes: { att: " #{x} attribute" } 
      end
    end
  
     expect( base_document.a_link_set ).to have(9).items
    # reload document
     reloaded_document =  base_document.reload!
     expect( reloaded_document.a_link_set).to have(9).items
     reloaded_document.a_link_set.each{|x| expect(x).to be_a REST::Model }
   #  expect(base_document.to_link_class).to eq link_document

    end
      

  end

  context "Operate with an embedded object" , focus: true do
    before(:all) do 
      @r.delete_class  'Testbaseclass'

      @base_class = @r.create_class 'Testbaseclass'
      @base_class.create_property field: 'to_data', type: 'embeddedlist', linked_class: 'FLOAT'
#      @base_class.create_property field: 'a_link_set', type: 'linkset', linked_class: @link_class
    
    end
    it "work with a schemaless approach" do
  
      emb = [1,"  2  ","zu",1]
      base_document = @base_class.new_document attributes: { embedded_item: emb }
      expect(base_document.embedded_item).to eq emb

      base_document.update_embedded :embedded_item, " zU"
      expect(base_document.embedded_item).to eq emb << " zU"

      reloaded_document =  base_document.reload!
      expect(reloaded_document.embedded_item).to eq emb
  
    end

    it "work with embeddedlist" do
      emb = [1,2,"zu",1]
      nbase_document = @base_class.new_document attributes: { to_data: emb }
      expect(nbase_document.to_data).to eq emb
      nbase_document.update_embedded :to_data, " 45"
      expect(nbase_document.to_data).to eq emb << " 45"

      reloaded_document =  @r.get_document nbase_document.rid
      expect(reloaded_document.to_data).to eq emb
      expect(reloaded_document.to_data).to eq [1,2,"zu",1, " 45"]  # Orientdb convertes " 45" to a numeric
    end
  end

 # context "Query", focus: true do

   #   before(:all){@testmodel.new_document attributes: { test: 45} }
      
#      it 
 # end

  context "ActiveRecord mimics"    do
   before(:all){ (0..45).each{|x| @testmodel.new_document :attributes => { test: x } }}
   it "fetch all documents into an Array" do
#      @testmodel.new_document attributes: { test: 45} 
      all_documents = @testmodel.all
      expect( all_documents ).to be_a Array #HashWithIndifferentAccess
      expect( all_documents ).to have_at_least(46).elements
      all_documents.each{|x| expect(x).to be_a REST::Model }
    end

    it "get a set of documents queried by where"  do
      all_documents = @testmodel.all  ## all fetches only 20 records
#      puts all_documents.map( &:test).join(' .. ')
      nr_23=  @testmodel.where  test: 23 
      expect( nr_23 ).to have(1).element
      expect( nr_23.first.test).to eq 23
      expect( @testmodel.all.size).to eq  46
    end
    it "datasets are unique only  on update" do
    expect{ @r.update_or_create_documents( o_class: @testmodel, :where => { test: 45 }) }. not_to change { @testmodel.all.size }
     expect{ @testmodel.new_document attributes: { test: 45} }.to change { @testmodel.all.size }
    end


    it "creates an edge between two documents" do
      node_1 =  @r.update_or_create_documents( o_class: @mynode, :where => { test: 23 } ).first 
      node_2  =  @r.update_or_create_documents( o_class: @mynode, :where => { test: 15 } ).first 
      node_3 = @r.update_or_create_documents( o_class: @mynode, :where => { test: 16 } ).first 
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
       expect( the_edge2).to eq the_edge
#      the_edge2= @myedge.create_edge( 
#			  attributes: { halbwertzeit: 46 }, 
#			  from: in_e,
#			  to:   in_e2  )
      expect( the_edge.out ).to eq node_1
      expect( the_edge.in ).to eq node_2
#      expect( the_edge2.out ).to eq in_e
#      expect( the_edge2.in ).to eq in_e2
      out_e =  @mynode.where(  test: 23  ).first 
      expect( out_e ).to eq node_1
      expect( out_e.attributes).to include 'out_Myedge'
      in_e = @mynode.where(  test: 15  ).first 
      puts in_e.attributes.inspect
      expect( node_1.attributes).to include 'in_Myedge'
     expect( node_1.Myedge).to have(1).item
     expect( node_1.myedge[0][:out].test).to eq 23
     expect( node_1.in_Myedge[0][:in].test).to eq  15
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

