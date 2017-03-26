
require 'spec_helper' 
require 'rest_helper'
require 'active_support'
require 'pp'

## Anything is performed in ActiveOrient
## There is no Action on the database
## These tests ensure that Namespacing is fully supported on the ruby-side
## and that proper database-class-names are generated
describe ActiveOrient::OrientDB do
    before(:all) do 
      #read_etl_data
      initialize_database
    end

    context "analyse initialized database" do
      it "classes array has the appropiate classes" do
	expect( ORD.class_hierarchy ).to eq ["E", ["V", ["hh_hipp_hurra", "hh_hurra", "hipp_hurra", "hurra", "hy_hipp_hurra", "hy_hurra"]]]
      end
      it "ActiveOrient handles model-files strict" do
	expect( ActiveOrient::Model.keep_models_without_file ).to be_nil
      end
      it "Only strict models are allocated" do
	expect( ActiveOrient::Model.allocated_classes.keys ).to eq ["V", "E", "hipp_hurra", "hurra"]
      end
    end

    context "assign to the proper context" do
      before( :all) do
	module HH; end
	module HY; end
      
      end
     it "change namespace to HH and allocate classes", focus: true do
       puts "CH:: #{ORD.class_hierarchy.inspect} "
puts "AC:: #{ActiveOrient::Model.allocated_classes.inspect}"
	ActiveOrient::Init.define_namespace { HH }
	expect( ActiveOrient::Model.namespace_prefix ).to eq ("hh_")
	puts "preallocation Namespace HH"
	module HH
	 O=  ActiveOrient::OrientDB.new  preallocate: true 

       puts "CH:: #{O.class_hierarchy.inspect} "
puts "AC:: #{ActiveOrient::Model.allocated_classes.inspect}"
	end
	expect( HH::O.class_hierarchy ).to eq ["E", ["V", ["hh_hipp_hurra", "hh_hurra", "hipp_hurra", "hurra", "hy_hipp_hurra", "hy_hurra"]]]
	expect( ActiveOrient::Model.allocated_classes.keys ).to eq ["V", "E", "hipp_hurra", "hurra"]
      end
    end
end
