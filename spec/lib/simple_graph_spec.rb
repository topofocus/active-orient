require 'spec_helper'
require 'model_helper'
require 'connect_helper'
require "rspec/given"
#require 'rest_helper'
#


def linear_elements start, count  #returns the edge created

	new_vertex = ->(n) {  ExtraNode.create( note_count: n)}
#	e= Connects.create from: start, to: new_vertex[1]
#	(2..count).each do |m|
#		e= Connects.create from: e.first.in , to: new_vertex[m]
#	end
	(2..count).each{|n| start = start.assign vertex: new_vertex[n], via: Connects }
end

RSpec.describe "E" do
  before( :all ) do
    @db = connect database: 'temp'

    V.create_class :base, :node
		Node.create_class :extra_node 
    c= E.create_class :connects
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
		Given( :first_item ){ Base.where(item: 'b').first }
														
		Then{ expect( first_item.attributes ).to have_key :out_connects }
		Then{ expect( first_item.out_connects).to have(10).items }

		Then{ expect( Node.count).to eq 110 }
		Then{ ExtraNode.count == 100 }
		context "has valid edges" do
				Then { expect(Base.where(item: 'b').first.out_connects).to have(10).items }
			(1..10).each do | n |
				Given( :the_node){  Node.where( item: n ).first }
				Then { the_node.in_connects.out  == Base.where(item: 'b') }
				Then { expect( the_node.out_connects.in).to have(10).items }
			end
		end
		#it " has valid edges" do
		#	(1..10).each do | n |
		#		the_node =  Node.where( item: n ).first
		#		expect( the_node.in_connects.out ).to eq Base.where(item: 'b')
		#		expect(Base.where(item: 'b').first.out_connects).to have(10).items
		#		expect( the_node.out_connects.in).to have(10).items

		#	end
		#end

		context " One to many connection"  do
			before(:all){ @c =  Base.create( item: 'c' ) }

			it "create the structue" do
				central_node =  Node.create item: 'center'
				peripherie_nodes =  (1..20).map{ |y|  ExtraNode.create item: y }
				Connects.create from: central_node, to: peripherie_nodes
				central_node.reload!
				expect(Connects.count).to be > 19
				expect(central_node.out_connects.count).to be >19
			end
		end


		context "linear graph" do

			before(:all) do
				start_node =  Base.create( item: 'l' ) 
				linear_elements start_node , 200
			end

			Given( :start_point ){ Base.where(  item: 'l' ).last }
			context "traverse {n} elements" do
				Given( :all_elements ) { start_point.traverse :out, via: /con/, depth: -1 }
				Then {  expect( all_elements.size).to eq 200 }
				Given( :hundred_elements ) { start_point.traverse :out, via: /con/, depth: 100 }
				Then {  expect( hundred_elements.size ).to eq 100 }
			end

			context ", get decent elements of the collection" do
				Given( :hundred_elements ) { start_point.traverse :out, via: /con/, depth: 100, execute: false }
				Given( :fetch_elements ) { start_point.query hundred_elements }
				Then {  expect( fetch_elements.size ).to eq 100 }  

				Given( :fifty_elements ) { start_point.traverse :out, via: /con/, depth: 100, start_at: 50}
				Then { expect( fifty_elements.size).to  eq 50 }
				Then { expect( fifty_elements.note_count ).to eq (51 .. 100).to_a }

				context "and apply median to the set" do
					Given( :median ) do 
						OrientSupport::OrientQuery.new from: hundred_elements, 
							projection: 'median(note_count)'  , 
							where: '$depth>=50 '
					end
					Then { median.to_s.ex_rid == "select median(note_count) from  ( traverse  outE('connects').in  from * while $depth < 100   )  where $depth>=50  " }

					Given( :median_q ){ @db.execute{ median.to_s }.first }
					Then {  median_q.keys == ["median(note_count)".to_sym] }
					Then {  expect( median_q.values).to eq [75.5] }
				end

			end
			
		end
	end
end


#### match ---> v3 --->  return expand(x) to operate on the expanded version on the resultset
