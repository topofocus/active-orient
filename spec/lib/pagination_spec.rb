=begin

Experiment to discover properties of the pagination mechanism

creates a test database and performs a simple pagination

(work in progress)

=end
require 'spec_helper'
require 'rest_helper'
require 'connect_helper'
require 'rspec/given'

def initialize_pagination	
   generate_word = -> { ('a'..'z').to_a.shuffle[0,5].join }
	 generate_number = -> { rand 999 }

	 (1 .. 200).each do |i|
		  Pagination.create col1: generate_word[], 
											col2: generate_number[],
											col3: generate_word[],
											col4: i
	 end

end


def paginate last_result =  []
	start = if last_result.empty?
						"#-1:-1"
					else 
						last_result.last.to_orient
					end
	
	Pagination.query_database " select from ( select from pagination  order by col2, col3 ) where @rid > #{start} limit 10" 

end

describe 'pagination excersise' do
	before( :all ) do
		@db = connect database: 'temp'
		@db.create_vertex_class :pagination
		if Pagination.count.zero?
			Pagination.create_property :col1 , type: :string
			Pagination.create_property :col2, type: :integer
			Pagination.create_property :col3, type: :string
			Pagination.create_property :col4, type: :integer
			Pagination.create_index :composite,  :on => [:col1, :col2, :col3], type: 'dictionary'

			initialize_pagination
		end



	end # before

#	after(:all){ @db.delete_database database: 'temp' }

	context "check Data" do
		subject {Pagination}
		its( :count ) { is_expected.to  eq 200 }
	end

	context "first 10 records" do
		Given( :first_datasets ){  Pagination.query_database "select from pagination  order by col4 limit 10" }
		Then { first_datasets.count ==  10 }
		Then { expect( first_datasets.col4 ).to eq [ 1,2,3,4,5,6,7,8,9,10 ] }
#		Then { expect( first_datasets.rid ).to eq [ 1,2,3,4,5,6,7,8,9,10 ] }
	end

	context "paginate" do
		 Given( :first_round ){ paginate }
		 Then { expect( first_round.count).to eq 10 }
		
	 
		 it "consecutive calls" do
			 result =  paginate
			 puts result.rrid.inspect
			 puts result.col2.inspect
			 

			 expect( result ).to be_a Array
			 result =  paginate( paginate )
			 puts result.rrid.inspect
			 puts result.col2.inspect
			 result =  paginate( paginate (paginate) )
			 puts result.col2.inspect
			 puts result.rrid.inspect
		 end
	end
	
	  

#	end

end

