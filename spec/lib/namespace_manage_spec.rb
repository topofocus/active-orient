
require 'spec_helper' 
require 'rest_helper'
require 'connect_helper'
#require 'active_support'
require 'pp'

## Anything is performed in ActiveOrient
## There is no Action on the database
## These tests ensure that Namespacing is fully supported on the ruby-side
## and that proper database-class-names are generated
describe ActiveOrient::OrientDB do
    before(:all) do 
    @db = connect database: 'temp'
 #     initialize_database
      read_etl_data
    end

#	after(:all){ @db.delete_database database: 'temp' }
    context "analyse initialized database" do
      it "classes array has the appropiate classes" do
	expect( ORD.class_hierarchy ).to eq ["E", ["V", ["hh_hipp_hurra", "hh_hurra", "hipp_hurra", "hurra", "hy_hipp_hurra", "hy_hurra"]]]
      end
      it "ActiveOrient handles model-files strict" do
	expect( ActiveOrient::Model.keep_models_without_file ).to be_nil
      end
      it "Only strict models are allocated" do
	expect( ActiveOrient.database_classes ).to eq ["V", "E", "hipp_hurra", "hurra"]
      end
    end

    context "assign to the proper context" do
      before( :all) do
	module HH; end
	module HY; end
      
      end
     it "change namespace to HH and allocate classes" do
       # allocate Object-Spaced Classes
       ActiveOrient::OrientDB.new  preallocate: true 
       ActiveOrient::Init.define_namespace { HH }
       expect( ActiveOrient::Model.namespace_prefix ).to eq ("hh_")
       # allocate HH-Prefixed classes
       ActiveOrient::OrientDB.new  preallocate: true 

       # allocate HY-Prefixed classes
       ActiveOrient::Init.define_namespace { HY }
       ActiveOrient::OrientDB.new  preallocate: true 

       expect( ORD.class_hierarchy ).to eq ["E", ["V", ["hh_hipp_hurra", "hh_hurra", "hipp_hurra", "hurra", "hy_hipp_hurra", "hy_hurra"]]]
       [ HH::HippHurra, HH::Hurra, HippHurra, Hurra, HY::Hurra, HY::HippHurra ].each do |m|
	 expect( m.new ).to be_a V 
       end	
       puts ActiveOrient::show_classes
     end
    end
end
