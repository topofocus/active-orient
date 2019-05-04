
require 'spec_helper'
require 'connect_helper'
require 'model_helper'
require 'rspec/given'

# create a star
def create_structure from
		
			if V2.count < 20
				vertices =  (1..10).map{|y| V2.create node: y}
				other_vertices =  (1..10).map{|y| V3.create node: y}

				E2.create from: from, to: vertices
				E3.create from: from, to: other_vertices
			end
			from  # return first node
			
end


RSpec.describe V do
  before( :all ) do
    @db = connect database: 'temp'
    V.create_class  :v1 
    V1.create_class :v2, :v3
   	E.create_class "e1"
		E1.create_class :e2 , :e3
		E3.create_class :e4

  end
#
#	after(:all){ @db.delete_database database: 'temp' }

	describe "CRUD" do
		Given( :the_vertex ){ V2.create a: "a", b: 2, c: [1,2,3] , d: {a: 'b'}}
		describe " create" do
		Then { expect( the_vertex.rrid).to match /^#[0-9]*:[0-9]*/   }
		end
		describe " read" do
			Given( :read_vertex ){ the_vertex.rrid.expand }
			Then { expect(read_vertex.object_id).not_to eq the_vertex.object_id}
			Then { expect(read_vertex.attributes).to eq the_vertex.attributes }
		end
		describe " update" do
			Given( :updated_vertex ){ the_vertex.update a: 'c' }
			Then { expect(updated_vertex.a).to eq 'c' }
		end
		describe "delete" do
			it "deletes the vertex" do
				my_vertex =  V2.where a: 'c'	
				 expect(my_vertex.size).to eq 1
				 rrid= my_vertex.first.rrid
				 my_vertex.first.delete
         expect( rrid.expand).to be_nil 
			end
		end
	end
	describe "creating a sample graph" do
		Given( :the_node ){ create_structure(V1.create( item: 1)  ) }
		Then{  expect( the_node.edges).to eq 1 }
		Then{ expect(E2.count).to eq 10 }
	end

	describe "analyse of vertex connections" do
		Given( :the_vertex ){ V2.where( node: 4 ).first }
		Given( :the_edges  ) { the_vertex.edges }
		Then { expect( the_edges).to be_a Array }
		Then { the_edges.each{|e| expect( e.rrid).to match /^#[0-9]*:[0-9]*/ } }
		
		describe "named edges are Edge-Instances by default" do
			Given( :named_edge ){ the_vertex.in_e2 }
			Then { expect(named_edge).to be_a Array  }
			Then { named_edge.each{|e| expect( e).to be_a E } }
		end
	end

end	
