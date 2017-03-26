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
      reset_database
    end


    context "the standard case" do
      it "allocate a new class in object-space" do
	my_classes = ORD.database_classes
	t = ORD.create_class 'test_1'
	expect( t ).to eq Test1
	t.delete_class
	expect(ORD.database_classes ).to eq my_classes
      end

      it "allocate a new namespaced class " do
	my_classes = ORD.database_classes
	module GH; end
	ActiveOrient::Init.define_namespace{  GH }

	t = ORD.create_class 'test_2'
	puts t.inspect
	expect( t ).to eq GH::Test2
	t.delete_class
	expect(ORD.database_classes ).to eq my_classes
      end
    end
    context  "proallocation of classes" do
      it "no prefix" do
	ActiveOrient::Init.define_namespace{  Object }

	result = ORD.allocate_class_in_ruby  'hurra'
	expect( result ).to eq Hurra
	expect( result.ref_name ).to eq 'hurra'
      end
      it "HH prefix" do
	module HH; end	  # working-module-name
	ActiveOrient::Init.define_namespace{  HH }

	result = ORD.allocate_class_in_ruby  'hh_hurry'
	expect( result ).to eq HH::Hurry
	expect( result.ref_name ).to eq 'hh_hurry'
	
	result = ORD.allocate_class_in_ruby  'hipp_hurry'
	expect( result ).to eq HH::HippHurry
	expect( result.ref_name ).to eq 'hipp_hurry'
     end
      it "HY prefix, same classes as HH" do
	module HY; end	  # working-module-name
	ActiveOrient::Init.define_namespace{  HY }

	result = ORD.allocate_class_in_ruby 'hy_hipp_hurry' 
	expect( result ).to eq HY::HippHurry
	expect( result.ref_name ).to eq 'hy_hipp_hurry'

	puts ActiveOrient::show_classes
     end

    end

end

