
require 'spec_helper'
require 'active_support'

describe REST::Model do
  before( :all ) do

    # working-database: hc_database
    REST::Base.logger = Logger.new('/dev/stdout')

    @r= REST::OrientDB.new database: 'hc_database' , :connect => false
    REST::Model.orientdb  =  @r
     @r.delete_class 'modeltest'
    @testmodel = @r.create_class "modeltest" 
    @myedge = @r.create_edge_class name: 'Myedge'
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

    it "repeatedly instantiated Mode-Objects are allocated once" do
      second =  REST::Model.orientdb_class name: 'Test' 
      expect( second).to eq subject
    end
  end


  context "Add a document to the class" do
    it "create a document" do
      before   =  @testmodel.count_documents 
      new_document= @testmodel.new_document attributes: { test: 45} 
      after = @testmodel.count_documents   
      expect( before +1 ).to eq after

      expect(new_document).to be_a REST::Model::Modeltest
      expect(new_document.test).to eq 45
    end  

    it "the document can be retrieved by all" do
      all = @testmodel.all
      expect(all).to be_a Array
      expect(all.size).to eq 1
      expect(all.first).to  be_a REST::Model::Modeltest
      expect(all.first.test).to eq 45
    end
  end
  context "ActiveRecord mimics" do
    it "fetch all documents into an Array" do
      all_documents = @testmodel.all
      expect( all_documents ).to be_a Array #HashWithIndifferentAccess
      expect( all_documents ).to have_at_least(1).element
      all_documents.each{|x| expect(x).to be_a REST::Model }
    end

    it "get a set of documents queried by where" do
      (1..45).each{|x| @testmodel.new_document :attributes => { test: x } }
      expect( @testmodel.count_documents ).to eq 46
      all_documents = @testmodel.all  ## all fetches only 20 records
      puts all_documents.map( &:test).join(' .. ')
      nr_23=  @testmodel.where :attributes => { test: 23 }
      expect( nr_23 ).to have(1).element
      expect( nr_23.first.test).to eq 23

      expect( @testmodel.all.size).to eq  46


    end

    it "creates an edge between two documents"  do
      out_e =  @testmodel.where( :attributes => { test: 23 } ).first 
      in_e = @testmodel.where( :attributes => { test: 15 } ).first 
      the_edge= @myedge.create_edge(attributes: { halbwertzeit: 45 }, 
			  from: out_e,
			  to:   in_e )
      expect( the_edge).to be_a REST::Model
      expect( the_edge.out ).to eq out_e.link
      expect( the_edge.in ).to eq in_e.link
      out_e =  @testmodel.where( :attributes => { test: 23 } ).first 
      expect( out_e.attributes).to include 'out_Myedge'
      in_e = @testmodel.where( :attributes => { test: 15 } ).first 
      expect( in_e.attributes).to include 'in_Myedge'
    end

    it "deletes an edge" do
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
