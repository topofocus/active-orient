require 'spec_helper'
require 'rest_helper'
require 'active_support'
require 'pp'

describe ActiveOrient::OrientDB do
    before(:all) do 
      reset_database
      ORD.create_class "V","E"
      ORD.create_vertex_class 'dataset', :the_dataset
      ORD.create_class 'linked_data'
    end

  #  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }



  context "create ActiveOrient::Model classes"  do
    before(:all) do

      # create classes Abstract, Depends and DependsOn
      ORD.create_class( 'abstract') do  { abstract: true } end
     ORD.create_class( 'depends') { Abstract }
     ORD.create_class( 'depends_on' ){ Depends }
    end

   it 'create an abstract class' do
     expect( Abstract.superclass ).to be ActiveOrient::Model 
   end
   it 'created a class_hierachie in class  Depends'  do
     expect( Depends.new).to be_a ActiveOrient::Base
     expect( Depends.new).to be_a ActiveOrient::Model
     expect( Depends.ancestors[1..2] ).to eq [Abstract, ActiveOrient::Model]
     expect( Depends.superclass ).to be Abstract
     expect( Depends.superclass.superclass ).to be ActiveOrient::Model
     expect( Depends.superclass.superclass.superclass ).to be ActiveOrient::Base
   end
   it 'ensure that methods defined later are passed through the object-tree' do
     class Abstract # :nodoc:
       def test
	  "test"
       end
     end
      doa = Depends.new
      expect(  doa.test).to eq "test"
   end

   it "operations on dependson" do
     expect( DependsOn.new ).to be_a ActiveOrient::Model
     expect( DependsOn.superclass).to be Depends
     doa  = DependsOn.new
     expect( doa.test).to eq "test" ## this works only if the previous test is performed prior to this one
   end

#   ## raises NameError:  uninitialized Constant Quatsch
#   it "allocate with a non existing superclass", focus:true do
#     ActiveOrient::Model.orientdb_class name: 'quatsch', superclass: 'unsinn'
#     expect( Quatsch.new ).to be_a ActiveOrient::Model
#     expect( Quatsch.superclass ).to be Unsinn
#     expect( Unsinn.superclass).to be ActiveOrient::Model
#   end
  end





  context "create classes" do
    
    it "create a single class" do
       ORD.create_class "erste_klasse"
      expect( ErsteKlasse.new ).to be_a ActiveOrient::Model
      expect( ErsteKlasse.ref_name).to eq "erste_klasse"
      m= ORD.create_class "erste_SYMBOL_klasse"
      expect(m).to be ErsteSymbolKlasse
      expect(m.ref_name).to eq "erste_SYMBOL_klasse"
    end

    #    ## deactivated for now
#    it "create a class hierachy "  do
#      cl_hash= { Z: [ :test1, :test2, 'test3'], :UZ => 'reisser' }
#      
#      m =  Hash[ ORD.create_class( cl_hash ){ ORD.create_class( 'GT') } ]
#      expect(m).to eq  Z  => [Test1, Test2, Test3], UZ => Reisser  
#    end
#
#    it "complex hierarchy"  do
#
#      m= Hash[ ORD.create_class( { TZV: [ :A, :B, C: [:c1,:c3,:c2]  ],  EIZR: [:has_content, :becomes_hot ]} ) ]
#      expect(  m.keys ).to eq [TZV, EIZR ]
#      expect( m[TZV] ).to eq [A, B, [[C, [C1, C3, C2]]]]
#      expect( m[EIZR] ).to eq [HasContent, BecomesHot]
#
#    end
      it "create  vertex classes through block" do
	classes_simple = [ :one_z, :two_z, :three_z]
        klasses = ORD.create_class( *classes_simple ){ 'V' }
        classes_simple.each{|y| expect( ActiveOrient.database_classes.keys).to include y.to_s }
	expect( klasses ).to have( 3 ).items
        klasses.each{|x| expect(x.superclass).to eq V }
      end
      it "create and delete an Edge " do
	edge_name = 'the_edge'
#	ActiveOrient::Model::E.delete_class
        model = ORD.create_edge_class  edge_name
        expect( model.new ).to be_a ActiveOrient::Model
        expect( model.superclass ).to eq E 
        ## a freshly initiated edge does not have "in" and "out" properties and thus does not look like an edge
        expect( model.new.is_edge? ).to be_falsy
        expect( ORD.classname  model ).to eq edge_name.underscore
        model.delete_class
        expect( ORD.database_classes ).not_to include edge_name 
      end
  end

  context "create and delete records "  do
    before(:all) do

      ORD.create_edge_class :the_edge 
      ORD.create_vertex_class :vertex1,:vertex2 
    end
    
    it "populate database-table with data and subsequent delete them" do
      records = (1 .. 100).map{|y| Vertex1.create testentry: y }
      cachesize= ActiveOrient::Base.display_rid.size
      expect( Vertex1.count ).to eq 100
      expect( records ).to have(100).items
      Vertex1.delete_record  *records
      expect( Vertex1.count ).to be_zero
      newcachesize= ActiveOrient::Base.display_rid.size
      expect( cachesize - newcachesize).to eq 100
   end

    it "populate database with data and connect them via an edge"  do
      record1 = (0 .. 99).map{|y| Vertex1.create testentry: y  }
      record2 = (:a .. :z).map{|y| Vertex2.create testentry: y  }
      expect(record1).to have(100).items
      expect(record2).to have(26).items

      cachesize= ActiveOrient::Base.display_rid.size

      expect {
      DB.create_edge TheEdge do  | attributes |
	 ('a'.ord .. 'z'.ord).map do |o| 
	       { from: record1.find{|x| x.testentry == o },
		 to: record2.find{ |x| x.testentry.to_s.ord == o } ,
		 attributes: attributes.merge( key: o.chr ) }
	  end
      end }.to change{ TheEdge.count }

      newcachesize= ActiveOrient::Base.display_rid.size
      expect( cachesize - newcachesize).to  be > 0
    end

  end

  context "populate records with data"  do

  context "update records "  do
    before(:all) do
      TheDataset.create_property :the_date, type: 'Date', index: :unique
      TheDataset.create_property :the_value, type: 'String' , index: :unique
      TheDataset.create_property :the_other_element, type: 'String'

    end

    it "add to records"  do
      TheDataset.create the_value: 'TestValue', the_other_value: 'a string', 
				    the_date: Date.new(2015,11,11) 
      TheDataset.create the_value: 'TestValue2', the_other_value: 'a string2', 
				    the_date: Date.new(2015,11,14) 
      expect( TheDataset.count).to eq 2
    end

    it "update via upsert" do
      TheDataset.create  the_value: 'TestValue3', the_other_value: 'a string2', 
				    the_date: Date.new(2015,11,17) 
      ## insert dataset
      expect{ @orginal= DB.upsert TheDataset, set: {the_value: 'TestValue4', the_other_value: 'a string2'}, 
			    where: {the_date: Date.new(2015,11,15) } }.to change{ TheDataset.count }.by 1
      ## update dataset
#     orginal = ORD.get_records(from: TheDataset, where: { the_date: Date.new(2015,11,14) }, limit: 1).pop
     expect{ @updated= DB.upsert TheDataset, set: {the_value: 'TestValue5', the_other_value: 'a string6'}, 
			      where: { the_date: Date.new(2015,11,14) } }.not_to change { TheDataset.count }

     # updated = ORD.get_records(from: TheDataset, where: { the_date: Date.new(2015,11,14) }, limit: 1).pop
     #puts "The original: "+ @orginal.to_human
     #puts "The update  : "+ @updated.to_human
     expect( @orginal.the_value).not_to eq @updated.the_value

     # insert dataset and perfom action with created object
     new_record = DB.upsert( TheDataset, 
				   set: {the_value: 'TestValue40', the_other_value: 'a string02'}, 
				   where: {the_date: Date.new(2015,11,14)} ) do | the_new_record |
				  # expect( the_new_record ).to be_a ActiveOrient::Model
				  # expect( the_new_record.the_value).to eq 'TestValue40'
				   end
#				     }.to change{ TheDataset.count }.by 1
     expect( new_record.the_value ).to eq 'TestValue40' 

    end
    end
  end
 # this interferes with other test, thus placing it to the end
  context "play with naming conventions" do

    it "the standard case" do
      m = ORD.create_class "erster_test"
      expect(m).to be ErsterTest
      expect(m.ref_name).to eq "erster_test"
    end

    it "change the naming convention"  do
      ## We want to represent all Edges with Uppercase-Letters
      class E < ActiveOrient::Model  # :nodoc:
	def self.naming_convention name=nil
	  name.present? ? name.upcase : ref_name.upcase
	end
      end

      m = ORD.create_class( "zweiter" ){ :E }
      puts m.classname
      expect(m.superclass).to be E
      expect(m).to be ZWEITER
      expect(m.ref_name).to eq "zweiter"
     
    end
  end
end
