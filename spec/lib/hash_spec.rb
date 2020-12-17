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
		TestModel.create  ll:  { a:'test', :z => 57 , 'zu' => 7988 }   

	end

  context "add and populate an Hash"  do
		 Given(:record ){ TestModel.first } 

      Then {record.ll.is_a? Hash }

      Then { record.ll.first == [:a,"test"] }   # contains array
      Then { record.ll[:z] == 57 }               # contains numeric
			Then { record.ll.keys == [ :a, :z, :zu ] }  # keys and values 
			Then { record.ll.values == [ 'test',  57, 7988 ] }
			Then { record.ll.size == 3 }
	end
	context "modify the Object"  do
			before(:all){ TestModel.first.ll.merge zu: 78, bla: [8,9,10] }
			Given( :modified_hash ){  TestModel.first.ll }
			Then {  modified_hash[:bla] == [8,9,10] } # item added
			Then {  modified_hash[:zu] == 78 }        # item changed
			Then {  modified_hash.size == 4 }
	end

	context "remove content from Hash"	do
		  before(:all ) { TestModel.first.ll.remove :bla }
			Given( :partial_hash ){  TestModel.first.ll }
			Then { partial_hash.size == 3 }
			Then { partial_hash[:bla] ==  :ll }  # if the item is not present, a symbol is returned

	end

	context "a Hash with links "   do
		before do 

			record =  TestModel.create ll: {}
			#tj = []
			(0..99).each do |i|
			#	tj << Thread.new do
					record.ll[ "item_#{i}" ] = LinkClass.create( linked_item: i*i, value: "a value #{i+4}" ) 
			#	end
			end
		#	tj.join()
		end
#		it{ sleep 6.0; puts  }  #  to synchronize threaded allocation of datasets in |before :all|
		Given( :linked_items ) { TestModel.last.ll }

		Then { linked_items.size == 100 }
		Then { linked_items.map{|_,y| y.is_a?( ActiveOrient::Model )}.uniq  == [true] }




	end

end
