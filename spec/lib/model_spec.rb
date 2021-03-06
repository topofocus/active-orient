
require 'spec_helper'
require 'connect_helper'
require 'model_helper'
require 'rspec/given'
module ActiveOrient
  class Base
    def self.get_riid
      @@rid_store
    end
  end
end

describe ActiveOrient::Model do
  before( :all ) do
    @db = connect database: 'temp'
		@db.create_class :work 
    V.create_class :test_model, :test_model2, :my_node  # creates class TestModel, TestModel2
		E.create_class :my_edge 
		TestModel2.create_property :c, type: :integer, index: :unique
  end
#	after(:all){ @db.delete_database database: 'temp' }

  context "create standalone ActiveOrient::Model classes" do
    subject { ActiveOrient::Model.orientdb_class name: 'Test' }
    it { is_expected.to be_a Class }
    its( :logger) { is_expected.to be_a Logger }
    its( :orientdb) { is_expected.to be_a ActiveOrient::OrientDB }
    if RUBY_PLATFORM == 'java'
			its( :db) { is_expected.to be_a ActiveOrient::API }
    else
			its( :db) { is_expected.to be_a ActiveOrient::OrientDB }
    end

    it "a Model-Instance inherents logger and db-reference" do
      object =  subject.new
      expect( object.logger ).to be_a Logger
      expect( object.db ).to be_a ActiveOrient::OrientDB
    end

    it "repeatedly instantiated Model-Objects are allocated once" do
      second =  ActiveOrient::Model.orientdb_class name: 'Test'
      expect( second).to eq subject
    end
  end  #context

  context "The Models have proper superClasses"  do

    it "A document class has an empty superClass" do
      expect( Work.superclass ).to eq  ActiveOrient::Model
    end
    it "An Vertex inherents from »V«" do
      expect( MyNode.superclass ).to eq  V 
    end
    it "An Edge inherents from »E«" do
      expect( MY_EDGE.superclass ).to eq E
    end
  end  # context

	######################### documents #########################################
	context "Create a new document"   do

		context "new document"  do
			subject{  Work.new w_att: 'Attribute' }
			it { is_expected.to be_a Work }
			its( :w_att ){ is_expected.to eq 'Attribute' }
			its( :rid   ){ is_expected.to  eq ':'}
			its( :metadata ){ is_expected.to be_a(Hash) and be_empty }

		end

		context "save new document" do
			subject{  Work.new( w_att: 'Attribute').save  }
			it_behaves_like 'a new record' 
				it " save it now" do
				n =  Work.new w_att: 'Attribute' 
				n.save
				expect( n.rid.rid? ).to be_truthy
				n.w_att = "New_Attribute"
				expect{ n.save }.to change{ n.version }.by 1
			end 
		end
	end


  context "Add and modify documents"  do
		before(:all){  TestModel.delete all: true }  # empty the class (focus: true is possible)
	
    it "put some data into the class"  do
			TestModel.delete all: true 
			(0..45).each{|x| TestModel.create(  test: x ) }
			
			expect( TestModel.count ).to eq 46
		end

		it "the database is empty before we start"  do
			TestModel.delete all: true
      expect( TestModel.all ).to be_empty
      expect( @db.get_documents  from: TestModel ).to be_empty
      expect( TestModel.count ).to be_zero
    end

		context " create an document"  do
			Given( :obj ){ TestModel.create test: 145  }
			Then { obj.test == 145 }
			Then { expect(obj).to be_a ActiveOrient::Model }
			##### Method Missing [:to_ary] ---> Dokumente werden wahrscheinlich aus dem Cash genommen
			#und nicht von der Datenbank abgefragt
	  	it "the document can be updated " do
				the_object =  TestModel.create( test: 144 )
				expect( the_object.attributes ).to eq test: 144
				o= the_object.update test: 177, new_entry: "This is a new Entry"   
				expect( the_object).to eq  o                          # flags: update was successful
				expect( the_object.test).to eq  177                    # confirmation, attributes have changed
				expect( the_object.new_entry).to be_a String 
			end

			it "various Properties can be added to the document" do
				aa = [ 1,4,'r', :r ]  
				ah = { :a => 'b', b: 2, c: :d } 
				eh = { "a" => "b" , "b" => 2, "c" => :d  }

				the_object =  TestModel.create( test: 146)
				the_object.update set: { a_array: aa  , a_hash: eh }   
				#puts  the_object.inspect
				expect( the_object.a_array ).to eq aa
				expect( the_object.a_hash ).to eq  ah   # Hash-keys are always symbols!!
			end

			it "a value can be added to the array (append)" do

				the_object =  TestModel.create( test: 147, aa: [ 1,4,'r', :r ]  )

				the_updated_object = the_object.update a_array: [1,4,'r',:r] 
				expect(  the_updated_object.a_array).to eq  [1,4,'r',:r]  
			  the_updated_object.a_array.append 56 
				expect( the_updated_object.a_array).to eq  [ 1,4,'r', :r , 56] 
			end
		end

    it "the document can be deleted"  do
			d =  TestModel.create test: 156  # does not work using obj
			puts "d: #{d.to_human}"
			c = TestModel.count
      d.delete  
			expect( TestModel.count ).to eq c - 1
    end
  end #context

  context "ActiveRecord mimics"   do
		before(:all) do 
			TestModel.delete all: true
			TestModel.create_property :test, type: :integer,   index: :unique
			(0..45).each{|x| TestModel.create  test: x  }
			#@db.database_classes requery: true
		end
		it{  expect( TestModel.indexes.first['fields'] ).to eq ["test"] }
		context "fetch all documents into an Array" do
      Given( :all_documents) { TestModel.all }
      Then { expect( all_documents ).to be_a Array  }
      Then { expect( all_documents ).to have_at_least(45).elements }
      Then { all_documents.each{|x| expect(x).to be_a ActiveOrient::Model }  }
    end

    context "get a set of documents queried by where"   do
      Given( :nr_23 ) {  TestModel.where  test: 23 }
      Then { expect( nr_23 ).to have(1).element }
      Then { expect( nr_23.first.test).to eq 23 }
    end
    it "datasets are unique only  on update"  do
      expect{ TestModel.upsert(  :where => { test: 45 }) }. not_to change { TestModel.count }
			## raises an error thus preventing thes spec to run. 
##      expect{ TestModel.create  test: 45 }.not_to change { TestModel.count }
			# upsert returns the affected document
      expect( TestModel.upsert(  :where => { test: 46 }) ).to be_a TestModel
    end


    it "specific datasets can be manipulated" do
      expect( TestModel.where( 'test > 40' ) ).to have(6).elements
      expect( TestModel.update_all( set: { new_ds: 45 }, where: 'test > 40')).to eq 6
      expect( TestModel.where( new_ds: 45 ) ).to have(6).elements
    end

    it "specific datasets can be removed" do
      count= TestModel.update_all( set: { new_ds: 45 }, where: 'test > 40')
      expect( TestModel.delete(  where: {test: 42})).to eq 1
      expect( TestModel.where( new_ds: 45 ) ).to have( count - 1 ).elements
    end

let( :node_1) { TestModel.where( test: 45 ).first }
let( :node_2) { TestModel.where( test: 2 ).first }
let( :node_3) { TestModel.where( test: 16 ).first }

    it "creates an edge between two vertices"   do
      [ node_1, node_2 ].each{|y| expect( y ).to be_a V }
      the_edge = MY_EDGE.create(  halbwertzeit: 655, from: node_1, to: node_2  )
      expect( the_edge ).to be_a E
      expect( the_edge.in ).to eq node_2
      expect( the_edge.out ).to eq node_1
			puts "node_1:  #{node_1}"
		end

		it "create a second edge" do
			the_edge =  MY_EDGE.where( halbwertzeit: 655 ).first
      the_edge2= E.create( set: { halbwertzeit: 655 }, from: node_1, to:   node_2  )
      expect( the_edge.rid ).not_to eq the_edge2.rid
      expect( the_edge2.out ).to eq  node_1
    end

    it "deletes an edge"  do
      the_edges =  E.all
      expect(the_edges.size).to  be >=1
      the_edges.each{ |edge| edge.delete }
      expect(E.count).to eq 0
    end

  end

	context "upsert returns a valid dataset" do
		before( :all ) { TestModel2.delete all: true }    # erase any content from TestModel

		context " on a new record " do
			subject  { TestModel2.upsert set: { a: 5, b:7 }, where: { c: 8 } }
			it_behaves_like 'a new record'
		end

		context "on an updated record " do
			context  "add a dataset" do
				subject{  TestModel2.upsert set: { a: 5, b:7 }, where: { c: 9 } }
				it_behaves_like 'a new record'
			end
			context "update a dataset" do
					
				subject{ TestModel2.upsert set: { a: 6, b:7 }, where: { c: 9 } }
				it_behaves_like 'a valid record'
				its( :version ){ is_expected.to be > 1}
				its( :a ){ is_expected.to eq 6 }
			end
		end
	end
end
