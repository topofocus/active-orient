require 'spec_helper'
require 'connect_helper'
require 'rest_helper'
require 'rspec/given'

describe 'Properties and Application of Hashes' do
	before( :all ) do
		db = connect database: 'temp'
		db.delete_database database: 'temp' 

		db = connect database: 'temp'
		db.create_class "test_model"
		db.create_class 'link_class'
		# the test records
		TestModel.create  ll:  { a:'test', b: 5, 8 => 57 , 'zu' => 7988 }   

		record =  TestModel.create ll: {}
		tj = []
		(0..99).each do |i|
			tj << Thread.new do
				record.ll[ "item_#{i}" ] = LinkClass.create( linked_item: i*i, value: "a value #{i+4}" ) 
			end
		end
		tj.join()
	end

  context "add and populate an Hash"  do
		 Given(:record ){ TestModel.first } 

      Then {record.ll.is_a? Hash }

      Then { record.ll.first == [:a,"test"] }   # contains array
      Then { record.ll[:b] == 5 }               # contains numeric
			Then { record.ll.keys == [ :a, :b, 8, :zu ] }  # keys and values 
			Then { record.ll.values == [ 'test', 5, 57, 7988 ] }
			Then { record.ll.size == 4 }
	end
	context "modify the Object"  do
			before(:all){ TestModel.first.ll.merge zu: 78, bla: [8,9,10] }
			Given( :modified_hash ){  TestModel.first.ll }
			Then {  modified_hash[:bla] == [8,9,10] } # item added
			Then {  modified_hash[:zu] == 78 }        # item changed
			Then {  modified_hash.size == 5 }
	end

	context "remove content from Hash"	do
		  before(:all ) { TestModel.first.ll.remove :bla }
			Given( :partial_hash ){  TestModel.first.ll }
			Then { partial_hash.size == 4 }
			Then { partial_hash[:bla] ==  :ll }  # if the item is not present, a symbol is returned

	end

	context "a Hash with links "   do
		it{ sleep 1.5 }  #  to synchonize threaded allocation of datasets in |before :all|
		Given( :linked_items ) { TestModel.last.ll }

		Then { linked_items.size == 100 }
		Then { linked_items.map{|_,y| y.is_a?( ActiveOrient::Model )}.uniq  == [true] }




	end

end
