require 'spec_helper'
require 'model_helper'
require 'connect_helper'
#require 'rest_helper'
#

describe "E" do
  before( :all ) do
    @db = connect database: 'temp'

    @db.create_vertex_class :base, :node
		@db.create_class( :extra_node ){ Node }
    c= @db.create_edge_class :connects
    c.uniq_index
  end
	after(:all){ @db.delete_database database: 'temp' }



	context "Connect some vertices" do
	  before(:all) do
			b =	 Base.create( item: 'b' )
			(1..10).map do |n| 
				new_node =  Node.create( item: n)   
				(1..10).map{|i|	Connects.create from: new_node, to: ExtraNode.create( item: new_node.item**2), attributes:{ extra: true } }
				Connects.create from: b, to: new_node, attributes: {basic: true}
			end
		end
		subject{ Base.where(item: 'b').first }
														
		its( :attributes ){ is_expected.to have_key :out_connects }
		its( :out_connects ){ is_expected.to have(10).items }

		it{ expect(Node.count).to  eq 110 }
		it{ expect(ExtraNode.count).to  eq 100 }
		it " has valid edges" do
			(1..10).each do | n |
				the_node =  Node.where( item: n ).first
				expect( the_node.in_connects.out ).to eq Base.where(item: 'b')
				expect(Base.where(item: 'b').first.out_connects).to have(10).items
				expect( the_node.out_connects.in).to have(10).items

			end
		end

		context " One to many connection" do
			before(:all){ @c =  Base.create( item: 'c' ) }

			it "create the structue" do
				central_node =  Node.create item: 'center'
				peripherie_nodes =  (1..20).map{ |y|  ExtraNode.create item: y }
				Connects.create from: central_node, to: peripherie_nodes

				expect(Connects.count).to be > 19
				expect(central_node.out_connects.count).to be >19
			end


		end
	end
end
