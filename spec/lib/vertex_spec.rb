
require 'spec_helper'
require 'connect_helper'
require 'model_helper'
require 'rspec/given'

# create a star
def create_structure from
		
			if from.edges.empty?
				vertices =  (1..10).map{|y| V2.create node: y}
				other_vertices =  (1..10).map{|y| V3.create node: y}

				E2.create from: from, to: vertices
				E3.create from: from, to: other_vertices
			end
			  # return first node
				from
end

def linear_elements start, count  #returns the edge created

	new_vertex = ->(n) {  V2.create( note_count: n)}
	#start.assign vertex: new_vertex[1], via: E2
	ActiveOrient::Base.logger.level=2
	(2..count).each do |m|
		start = start.assign vertex: new_vertex[m], via: E2
	end
	ActiveOrient::Base.logger.level=1
end

def threaded_creation data
	th = []
	ActiveOrient::Base.logger.level=2
	V2.delete all: true
	data.map do |d|
		th << Thread.new do
			V2.create data: d
		end
	end
	th.each &:join # wait til all thread are finished
	ActiveOrient::Base.logger.level=1
  V2.count # return value
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
	after(:all){ @db.delete_database database: 'temp' }

	describe "CRUD" do
		Given( :the_vertex ){ V2.create a: "a", b: 2, c: [1,2,3] , d: {a: 'b'}}
		context " create" do
			Then { expect( the_vertex.rrid).to match /^#[0-9]*:[0-9]*/   }
		end
		context " read" do
			Given( :read_vertex ){ the_vertex.rrid.expand }
			Then { expect(read_vertex.object_id).not_to eq the_vertex.object_id}
			Then { expect(read_vertex.attributes).to eq the_vertex.attributes }
		end
		context " update" do
			Given( :updated_vertex ){ the_vertex.update a: 'c' }
			Then { expect(updated_vertex.a).to eq 'c' }
		end
		context "delete" do
			it "deletes the vertex" do
				my_vertex =  V2.where a: 'c'	
				 expect(my_vertex.size).to eq 1
				 rrid= my_vertex.first.rrid
				 expect{ my_vertex.first.delete }.to change{ V2.count }.by -1
#         expect( ).to be_nil 
			end
		end
	end
	describe "creating a sample graph"  do
		Given( :the_node ){ create_structure( V1.upsert( where:{ item: 1 }) ) }
		Then{ expect( the_node.reload!.to_human ).to match /out: {E2=>10, E3=>10}, item : 1>/ }
		Then{ the_node.edges( :out ).size ==  20 }
		Then{ the_node.edges( :in ).empty? }
		context "Analysing Edges" do
			Then{ the_node.edges( E2 ).size == 10 }
			Then{ the_node.edges( E3 ).size == 10 }
			Then{ the_node.edges( E2 , :in).empty? }
			Then{ the_node.edges( /e/ ).size ==  20 }
		end
		context "simulating nodes with edges" do
			Given( :the_edges ){ the_node.edges( E2, :out ) }
			Then{ the_edges.is_a? OrientSupport::Array }
			Then{ the_edges.in.map{|y| y.node} == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]  }
			Then{ the_edges.in.map{|y| y.node}  == the_node.nodes( via: E2 ).node  }
		end
		context "Analysing adjacent nodes" do
			Given( :the_nodes ){ the_node.nodes via: E3 }
			Then{ the_nodes.map( &:class ).uniq == [V3] }  
			Then{ the_nodes.size == 10 }
		end

	end

	describe "analyse of vertex connections" do
		Given( :the_vertex ){ V2.where( node: 4 ).first }
		Given( :the_edges  ) { the_vertex.edges }
		Then { expect( the_edges).to be_a Array }
		Then { the_edges.each{|e| expect( e.rrid).to match /^#[0-9]*:[0-9]*/ } }
		
		context "named edges are Edge-Instances by default" do
			Given( :named_edge ){ the_vertex.in_e2 }
			Then { expect(named_edge).to be_a Array  }
			Then { named_edge.each{|e| expect( e).to be_a E } }
		end
	end

	describe "linear graph"do
		before(:all) do
				start_node =   V1.upsert( where:{ item: 'l'} ) 
				linear_elements( start_node , 200) if start_node.edges.empty?
		end

	  context "the linear graph" do
			Given( :start_point ){  V1.upsert( where:{ item: 'l'}) } 
			Given( :all_elements ) { start_point.traverse :out, via: E2, depth: -1 }
				Then {  expect( all_elements.size).to eq 200 }
		end
	end	

	 describe "threaded creation" do
		  Given( :the_raw_data ){ (1 .. 10000).map{ |y|   Math.sin(y) } }
		 Then { expect(the_raw_data.size).to eq 10000 }
		
		 Given( :v3_count  ) { threaded_creation the_raw_data }


		 Then {  expect(v3_count).to eq 10000 } 

	 end
end	
