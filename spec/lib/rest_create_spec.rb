require 'spec_helper'
require 'active_support'
require 'pp'

describe ActiveOrient::OrientDB do

  #  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }

  before( :all ) do
   #ao =   ActiveOrient::OrientDB.new 
   #ao.delete_database database: 'RestTest'
   #ORD  =  ActiveOrient::OrientDB.new database: 'RestTest' 
    ORD.database_classes.each{|x| ORD.delete_class x }
  end


  context "create ActiveOrient::Model classes"  do
    let( :abstract ){ ActiveOrient::Model.orientdb_class name: 'abstract' }
    let( :depends ){ ActiveOrient::Model.orientdb_class name: 'depends', superclass: abstract }
    let( :dependson ){ ActiveOrient::Model.orientdb_class name: 'depends_on', superclass: 'depends' }

   it 'create a abstract class' do
     expect( abstract.superclass ).to be ActiveOrient::Model 
   end
   it 'create a class_hierachie' do
     expect(depends).to be ActiveOrient::Model::Depends
     expect(depends.superclass ).to be ActiveOrient::Model::Abstract
   end
   it 'ensure that methods defined later are passed through the object-tree' do
     class ActiveOrient::Model::Abstract
       def test
	  "test"
       end
     end
      doa = ActiveOrient::Model::Depends.new
      expect(  doa.test).to eq "test"
   end

   it "operations on dependson" do
     expect( dependson ).to be ActiveOrient::Model::DependsOn
     expect( dependson.superclass).to be ActiveOrient::Model::Depends
     doa  = dependson.new
     expect( doa.test).to eq "test" ## this works only if the previous test is performed prior to this one
   end


   it "allocate with a non existing superclass" do
     quatsch =  ActiveOrient::Model.orientdb_class name: 'quatsch', superclass: 'unsinn'
     expect( quatsch ).to be ActiveOrient::Model::Quatsch
     expect( quatsch.superclass ).to be ActiveOrient::Model::Unsinn
     expect( ActiveOrient::Model::Unsinn.superclass).to be ActiveOrient::Model
   end
  end


  context "initialize class hierachie from database"   do
    let( :orientclasses ){ ORD.get_class_hierarchy requery: true }

    it "orientdb-hierachy includes system classes" do
      expect( orientclasses ).to be_a Array
      ## systemclasses must be reduced from [OIdentity[ORole,OUser]]
      ORD.system_classes( abstract: true).each do | system_class |
	unless system_class == '_studio' ### this systemclass is not present until studio processed the database
	  expect( orientclasses.map{ |x| x if x.is_a? String} ).to include system_class
	end
      end
    end

    it "abstract-classes can be initialized" do
     classes= ORD.initialize_class_hierarchy
     pp classes.compact
    end

  end

  context "play with naming conventions" do
    it "database-free mode" do
      m = ActiveOrient::Model.orientdb_class  name:"zweiter_test"
     n = ActiveOrient::Model.orientdb_class  name:"drittertest"
      expect(m).to be ActiveOrient::Model::ZweiterTest
      expect(m.ref_name).to eq "zweiter_test"
      expect(n).to be ActiveOrient::Model::Drittertest
      expect(n.ref_name).to eq "drittertest"

    end

    it "the standard case" do
      m = ORD.open_class "erster_test"
      expect(m).to be ActiveOrient::Model::ErsterTest
      expect(m.ref_name).to eq "erster_test"
#      n = ORD.open_class "
    end

    it "change the naming convention" do
      ## We want to represent all Edges with Uppercase-Letters
      class ActiveOrient::Model::E < ActiveOrient::Model
	def self.naming_convention name=nil
	  name.present? ? name.upcase : ref_name.upcase
	end
      end

#      m = ActiveOrient::Model.orientdb_class  name:"zweiter", superclass: :E
 #     puts m.inspect
 #     puts m.superclass
#      ORD.create_class 'E
    ### if the block contains a Symbol, the test fails
      m = ORD.create_class( "zweiter"){  'E' }
      puts m.classname
      expect(m.superclass).to be ActiveOrient::Model::E
      expect(m).to be ActiveOrient::Model::ZWEITER
      expect(m.ref_name).to eq "zweiter"
     
    end
  end


  context "create classes"  do
      let( :classes_simple ) { ["one", "two" , "trhee"] }
      let( :classes_vertex ) { { V: [ :one_v, :two_v,  :trhee_v] } }
    
    it "create a single class" do
      m = ORD.create_class "erste_klasse"
      expect(m).to be ActiveOrient::Model::ErsteKlasse
      expect(m.ref_name).to eq "erste_klasse"
      m = ORD.create_class "erste_SYMBOL_klasse"
      expect(m).to be ActiveOrient::Model::ErsteSymbolKlasse
      expect(m.ref_name).to eq "erste_SYMBOL_klasse"
    end

    it "create a bunch of abstract classes" do
	m =  ORD.create_class classes_simple 
	expect(m).to have(3).items
	classes_simple.each_with_index do |c,i|
	  expect(m[i].ref_name).to eq c.to_s
	  classes_simple.each_with_index do |c,i|
	    expect(m[i].ref_name).to eq c.to_s
	    expect(m[i].superclass ).to be ActiveOrient::Model::V
	  end
	end

	    m.each{|x| x.delete_class } # remove const to enable reusing 
    end
    it "create a class hierachy " do
      cl_hash= { Z: [ :test1, :test2, 'test3'], UZ: 'reisser' }
      m = Hash[ ORD.create_class( cl_hash ){ "GT" } ]
      # {ActiveOrient::Model::Z=>[ActiveOrient::Model::Test1, 
      #				ActiveOrient::Model::Test2, 
      #				ActiveOrient::Model::Test3], 
      #	ActiveOrient::Model::UZ=>ActiveOrient::Model::Reisser}
      expect(m).to be_a Hash
      expect(m.keys).to have(2).items
      expect(m[m.keys.first]).to be_a Array
      m[m.keys.first].each{|x|  expect( x.to_s ).to match /ActiveOrient::Model/ }
      expect( m[m.keys.last].to_s).to match /ActiveOrient::Model/
    end

    it "complex hierarchy" do

      m= Hash[ ORD.create_class( { TZV: [ :A, :B, C: [:c1,:c3,:c2]  ],  EIZR: [:has_content, :becomes_hot ]} ) ]
#      puts m.inspect
      #{ActiveOrient::Model::TZV=>[ActiveOrient::Model::A, 
      #				  ActiveOrient::Model::B, 
      #				  [[ActiveOrient::Model::C, 
      #			    [ActiveOrient::Model::C1, ActiveOrient::Model::C3, ActiveOrient::Model::C2]]]],
      #	ActiveOrient::Model::EIZR=>[ActiveOrient::Model::HasContent, ActiveOrient::Model::BecomesHot]}
    end
      it "create  vertex classes through block" do
	classes_simple.each{|x| ORD.delete_class x }
        klasses = ORD.create_classes( classes_simple ){ 'V' }
        classes_simple.each{|y| expect( ORD.database_classes ).to include ORD.classname(y) }
	expect( klasses ).to have( 3 ).items
        klasses.each{|x| expect(x.superclass).to eq ActiveOrient::Model::V }
      end
      ## When creating multible classes through a hash, the allocated
      ## class-hierarchy is returned
      it "create Vertex classes through hash"  do
#	classes_simple.each{|x| ORD.delete_class x }
        klasses = ORD.create_classes( classes_vertex ) 
#        classes_vertex[:v].each{|y| expect( ORD.database_classes ).to include ORD.classname(y) }
	# klasses : {ActiveOrient::Model =>
	#	[ ActiveOrient::Model::V, ActiveOrient::Model::V, ActiveOrient::Model::V]]
	expect( klasses.keys.first).to be ActiveOrient::Model::V 
	expect( klasses.values.first ).to have(3).items
        klasses.values[0].each do |x|
          expect(x.superClass).to eq ActiveOrient::Model::V  => 'V'
        end
      end
      it "create and delete an Edge " do
	edge_name = 'the_edge'
#	ActiveOrient::Model::E.delete_class
        model = ORD.create_edge_class  edge_name
        expect( model.new ).to be_a ActiveOrient::Model
        expect( model.superClass ).to eq ActiveOrient::Model::E =>  "E"
        expect( model.to_s ).to eq "ActiveOrient::Model::#{edge_name.upcase}"
        ## a freshly initiated edge does not have "in" and "out" properties and thus does not look like an edge
        expect( model.new.is_edge? ).to be_falsy
        expect( ORD.classname  model ).to eq edge_name
        model.delete_class
        expect( ORD.database_classes ).not_to include edge_name 
      end
  end

  context "create and delete records "  do
    before(:all) do 
      TheEdge =  ORD.create_edge_class "TheEdge"
      Vertex1,Vertex2 =  ORD.create_classes([:Vertex1,:Vertex2]){:V}
    end
    
    it "populate database-table with data and subsequent delete them" do
      records = (1 .. 100).map{|y| Vertex1.create_document attributes:{ testentry: y } }
      expect( Vertex1.count ).to eq 100
      expect( records ).to have(100).items
      Vertex1.delete_record  *records
      expect( Vertex1.count).to be_zero
    end

    it "populate database with data and connect them via an edge" do
      record1 = (1 .. 100).map{|y| Vertex1.create_document attributes:{ testentry: y } }
      record2 = (:a .. :z).map{|y| Vertex2.create_document attributes:{ testentry: y } }
      expect(record1).to have(100).items
      expect(record2).to have(26).items

      ## create just sql-statements
      edges = ORD.create_edge TheEdge do  | attributes |
	 ('a'.ord .. 'z'.ord).map do |o| 
	       { from: record1.find{|x| x.testentry == o },
		 to: record2.find{ |x| x.testentry.ord == o } ,
		 attributes: attributes.merge( key: o.chr ) }
	  end
      end
    end

  end

  context "populate records with data" do
 before(:all) do
      Dataset =  ORD.create_vertex_class 'dataset'
      ORD.create_class 'linked_data'

  end

  context "update records "  do
    before(:all) do
      TheDataset =  ORD.create_vertex_class 'the_dataset'
      TheDataset.create_property :the_date, type: 'Date', index: :unique
      TheDataset.create_property :the_value, type: 'String' #, index: :unique
      TheDataset.create_property :the_other_element, type: 'String'

    end

    it "add to records"  do
      TheDataset.create_record  attributes: { the_value: 'TestValue', the_other_value: 'a string', 
				    the_date: Date.new(2015,11,11) }
      TheDataset.create_record  attributes: {the_value: 'TestValue2', the_other_value: 'a string2', 
				    the_date: Date.new(2015,11,14) }
      expect( TheDataset.count).to eq 2
    end

    it "update via upsert" do
      TheDataset.create_record  attributes: {the_value: 'TestValue3', the_other_value: 'a string2', 
				    the_date: Date.new(2015,11,17) }
      ## insert dataset
      expect{ @orginal= ORD.upsert TheDataset, set: {the_value: 'TestValue4', the_other_value: 'a string2'}, 
			    where: {the_date: Date.new(2015,11,15) } }.to change{ TheDataset.count }.by 1
      ## update dataset
#     orginal = ORD.get_records(from: TheDataset, where: { the_date: Date.new(2015,11,14) }, limit: 1).pop
     expect{ @updated= ORD.upsert TheDataset, set: {the_value: 'TestValue5', the_other_value: 'a string6'}, 
			      where: { the_date: Date.new(2015,11,14) } }.not_to change { TheDataset.count }

     # updated = ORD.get_records(from: TheDataset, where: { the_date: Date.new(2015,11,14) }, limit: 1).pop
     puts "The original: "+ @orginal.to_human
     puts "The update  : "+ @updated.to_human
     expect( @orginal.the_value).not_to eq @updated.the_value

     # insert dataset and perfom action with created object
     new_record = ORD.upsert( TheDataset, 
				   set: {the_value: 'TestValue40', the_other_value: 'a string02'}, 
				   where: {the_date: Date.new(2015,11,14)} ) do | the_new_record |
				   expect( the_new_record ).to be_a ActiveOrient::Model
				   expect( the_new_record.the_value).to eq 'TestValue40'
				   end
#				     }.to change{ TheDataset.count }.by 1
     expect( new_record.the_value ).to eq 'TestValue40' 

    end
    end
  end
end
