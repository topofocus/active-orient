
require 'spec_helper'
require 'connect_helper'
require 'model_helper'
require 'rspec/given'

RSpec.describe V do
  before( :all ) do
    @db = connect database: 'temp'
    @db.create_vertex_class  :v1  # creates class TestModel
    @db.create_class( :v2 ){ V1 }  # creates class TestModel
   	@db.create_edge_class "e1"
		@db.create_class( :e2 ){ E1 }
		@db.create_class( :e3 ){ E1 }
#
  end
#
#	after(:all){ @db.delete_database database: 'temp' }

	describe "creating a sample graph" do
		before( :all ) do
			if V2.count < 10
				vertices =  (1..10).map{|y| V2.create node: y}
				E2.create from: V1.create( item: 1  ), to: vertices
			end
		end

		it "check structure" do
			expect(E2.count).to eq 10
		end
	end

	describe "analyse of vertex connections" do
		Given( :the_vertex ){ V2.where( node: 4 ).first }
		Given( :the_edges  ) { the_vertex.edges }
		Then { expect( the_edges).to be_a Array }
		Then { the_edges.each{|e| expect( e.rid?).to be_truthy } }
		
		describe " named edges are Edge-Instances by default" do
			Given( :named_edge ){ the_vertex.in_e2 }
			Then { expect(named_edge).to be_a Array  }
			Then { named_edge.each{|e| expect( e).to be_a E } }
		end
	end

end	
