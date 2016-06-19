
require 'spec_helper'
require 'active_support'
require 'pp'

describe ActiveOrient::OrientDB do

  #  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }

  before( :all ) do
#    ORD.database_classes.each{|x| ORD.delete_class x }
   #ao =   ActiveOrient::OrientDB.new 
   ORD.delete_database database: 'temp'
   ORD  =  ActiveOrient::OrientDB.new database: 'temp'
#   @database_name = 'RestTest'
  end

  context "empty dataset" , :pending => true do 
    pending( 'Database Version 2.2 proviedes E,V and OSequence in Addition to Field in V2.1')
  
    it "the database has been created" do
      expect( ORD.get_databases ).to include 'RestTest'
    end
    it "the database is empty" do
      expect( ORD.get_database_classes requery: true).to be_empty
    end

    it "System classes are present" do
      classes = ORD.get_classes 'name', 'superClass'

      ["OFunction" ,
        "OIdentity" , "ORIDs" , "ORestricted" ,
        "ORole" , "OSchedule" , "OTriggered" , "OUser" ].each do |c|
	  puts c
          expect( classes.detect{ |x|  x['name'] == c } ).to be_truthy
        end
      end
  end

  context "manage a class hierachy"  do
    before(:all) do
      # create a simple class hierachie:
      # GT -> Z , UZ
      #  Z -> test1..3
      #  UZ -> reisser
      @cl_hash= { Z:[ 'test1', 'test2', 'test3'], UZ:  'reisser' }
      ORD.create_class( @cl_hash ){ "GT" } 

    end

    it 'classes have proper superclasses' do
      #pp ORD.get_classes.inspect
      #pp ORD.class_hierarchy base_class: 'GT'
      # class hierarchy is requeried on every execution of create_class 
      # thus, wie can depend on the array which we convert to a hash to access the key easily
      cl =  Hash[ ORD.class_hierarchy base_class: 'GT' ]
      expect(cl['Z']).to eq @cl_hash[:Z]
      # class hierachy always returns dependend classes as array
      # eg: Hash[ [["UZ", ["reisser"]]] ==> { "UZ" => ["reisser"] }
      expect(cl['UZ']).to eq [@cl_hash[:UZ]]
    end

    it 'get classes and hierarchy from db' do
     # first close the database by switching to test and then reopen the database
       classes =  ORD.get_classes
       ActiveOrient::OrientDB.new 
       r= ActiveOrient::OrientDB.new database: 'temp'
       expect( r.get_classes ).to eq classes
	@cl_hash[:Z].each do | classname |
	  o =  r.open_class classname
	  expect(o.ref_name).to eq classname
	  expect(o.superclass.ref_name).to eq "Z"
	end

    end
  end
    context "Manage Properties" do

      #describe "handle Properties at Class-Level"  do
        before(:all) do
	       ORD.create_classes ['exchange','Contract','property' ]
	end
        # after(:all){ ORD.delete_class 'property' }
	let( :predefined_property ) do
          rp = ORD.create_properties( ActiveOrient::Model::Property,
          symbol: { propertyType: 'STRING' },
          con_id: { propertyType: 'INTEGER' } ,
          exchanges: { propertyType: 'LINKLIST', linkedClass: 'exchange' } ,
          details: { propertyType: 'LINK', linkedClass: 'Contract' },
          date: { propertyType: 'DATE' }
          )
	end

      
	it "Properties can be assigned and read" do
	  predefined_property 
	  ['symbol','con_id','exchanges','details'].each do |property_name|
	    expect( ORD.get_class_properties( 'property')['properties'].map{|y| y['name']}).to include property_name
	  end
	end

	it "Properties are kept upon reopening the database" do
	  predefined_property

	  ActiveOrient::OrientDB.new 
	  r= ActiveOrient::OrientDB.new database: 'temp' 

	  ['symbol','con_id','exchanges','details'].each do |property_name|
	    expect( r.get_class_properties( 'property')['properties'].map{|y| y['name']}).to include property_name
	  end
	end

    end


end
