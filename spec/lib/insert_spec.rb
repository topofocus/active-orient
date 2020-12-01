require 'spec_helper'
require 'rest_helper'
require 'active_support'
require 'pp'
require 'connect_helper'
require 'rspec/given'
#####
#  Create Database-Classes and insert data
# 
#  Base: Vertex-class
####

describe V do
	before(:all){  @db = connect database: 'tema1p' }
	after(:all){ @db.delete_database database: 'tema1p' }

	context "schemaless environment"  do
		before(:all) { V.create_class :schemaless }
		Given( :s ){ Schemaless }
		Then{  expect( s.properties ).to  eq(:properties=>nil, :indexes=>nil) }
  end
	context "arguments are passed as hash and present as »to_orient«" do
		let( :attr ){ {a: 1, b: 'w', c: :z, d: ['a',1,:g], e: {u: 7}} }
		Given( :a_record ){ Schemaless.create attr }
		Then{ expect( a_record.attributes).to eq attr.map{|x,y| [x,y.to_orient]}.to_h}
		# in schemaless modus, fieldtypes are not used.
		Then{ expect( a_record.metadata[:fieldTypes] ).to be_nil }
		it{ puts a_record.metadata }
	end

	context "insert a link and follow by querying " do
		before(:all) do
			V.create_class :person 
			Person.create name: 'Hugo', 
				father: Person.upsert( where: { name: "Reimund" } ),
				children: ["Eva", "Ulli", "Uwe", "George"].map{|c| Person.create( name: c) }
		end
		
		Given( :hugo )  {Person.where( name: 'Hugo').first }
		Then {  hugo.father.name   == "Reimund" }
		Then {  hugo.children.name == ["Eva", "Ulli", "Uwe", "George"] }
		# still schemaless
		Then{ expect( hugo.metadata[:fieldTypes] ).to  eq "children=z,father=x" }

		context " query" do
			When( :father ){ Person.query.where( "father.name = 'Reimund'").execute }
			Then{ expect( father). to eq [hugo] } 
			context "declare property" do
				before( :all ) do
#				Person.create_property  :new_father, type: :link, linked_class: Person
#			Person.all{|y| puts y.to_human ; y.update new_father: y.father}
				end
				## update the record 
#				Given( :updated_hugo ){ hugo.update( new_father: hugo.father ) }
#				Then{ expect( updated_hugo.new_father.name ).to eq 'Reimund' }

				it "migrate father to link" do

					Person.print_properties
					Person.migrate_property :father, to: :link, linked_class: Person, via: "avc"
#					Person.migrate_property :children, to: :link_list, linked_class: Person, via: "dgt"
					Person.print_properties
				end
			end

			When( :children ){ Person.query.where( "children.name in ('Eva')").execute }
			Then{ children == [] }
			context "declare property" do
				before( :all ) do
				Person.create_property  :new_children, type: :link_list, linked_class: Person
#			Person.all{|y| puts y.to_human ; y.update new_father: y.father}
				end
#				## update the record 
				Given( :updated_hugo ){ hugo.update new_children: hugo.children  }
				Then{ expect( updated_hugo.new_children.name ).to eq ["Eva", "Ulli", "Uwe", "George"] }
			When( :children ){ Person.query.where( "new_children.name contains 'Eva'").execute }
				Then{ expect( children.first).to eq updated_hugo }
#
				it "delete and rename property" do
					Person.print_properties
					Person.delete_property :children
					#Person.alter_property  'new_children', attribute: 'name', alteration: 'children'
					V.db.execute{" alter property person.new_children name 'children'"}
					Person.print_properties
##					expect(Person.properties).to eq 1
			    expect( Person.query.where( "children.name contains 'Eva'").execute(reduce:true)).to eq hugo
#			   
				end

				When( :father ){ Person.query.where( 'father.name': 'Reimund' ).execute}
				Then{ father.first == updated_hugo }
				it{ puts "HUGO:  #{hugo.inspect}" }
			When( :children ){ Person.query.where( "children.name contains 'Eva'").execute }
				Then{ expect( children.first).to eq updated_hugo }
			end

		end
	end
end

