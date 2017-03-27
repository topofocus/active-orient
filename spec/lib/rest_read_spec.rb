
require 'spec_helper'
require 'rest_helper'
require 'active_support'
require 'pp'

describe ActiveOrient::OrientDB do

  #  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }

  before( :all ) do
    reset_database
  end

  context "empty dataset"  do 
  
    it "the database has been created" do
      expect( ORD.get_databases ).to include 'temp'
    end
    it "the freshly initialized  database contains E+V-Base-Classes" do
      expect( ActiveOrient.database_classes).to eq ["E","V"]
    end

    it "System classes are present" do
      classes = ORD.get_classes 'name', 'superClass'
# "ORIDs" , 
      ["OFunction" ,
        "OIdentity" ,"ORestricted" ,
        "ORole" , "OSchedule" , "OTriggered" , "OUser" ].each do |c|
	  puts c
          expect( classes.detect{ |x|  x['name'] == c } ).to be_truthy
        end
      end
  end

  # not supported anymore
#  context "manage a class hierachy"  do
#    before(:all) do
#      # create a simple class hierachie:
#      # GT -> Z , UZ
#      #  Z -> test1..3
#      #  UZ -> reisser
#      @cl_hash= { Z:[ 'test1', 'test2', 'test3'], UZ:  'reisser' }
#      ORD.create_class( @cl_hash ){ "GT" } 
#
#    end
#

#  end
    context "Manage Properties" do

      #describe "handle Properties at Class-Level"  do
        before(:all) do
	       ORD.create_class 'exchange','Contract','property' 
	end
        # after(:all){ ORD.delete_class 'property' }
	let( :predefined_property ) do
          rp = Property.create_properties(  symbol: { type: :string },
          con_id: { type: :integer } ,
          exchanges: { type: :linklist, linkedClass: 'exchange' } ,
          details: { type: :link, linkedClass: 'Contract' },
          date: { type: :date }
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
