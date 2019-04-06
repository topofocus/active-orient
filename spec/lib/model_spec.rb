
require 'spec_helper'
require 'connect_helper'
require 'model_helper'
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
    @db.create_vertex_class "test_model"  # creates class TestModel
    @db.create_vertex_class "test_model2"  # creates class TestModel
  end
	after(:all){ @db.delete_database database: 'temp' }

  context "create ActiveOrient::Model classes"  do
#  context "ActiveOrient::Model classes got a logger and a database-reference"  do

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
    before(:all) do
       @db.create_class :my_class 
       @db.create_vertex_class :my_node 
       @db.create_edge_class :my_edge 
    end
    it "A document class has an empty superClass" do
      expect( MyClass.superclass ).to eq  ActiveOrient::Model
    end
    it "An Vertex inherents from »V«" do
      expect( MyNode.superclass ).to eq  V 
    end
    it "An Edge inherents from »E«" do
      expect( MyEdge.superclass ).to eq E
    end
  end  # context

#  context "naming issues of classes"  do
#    ['Indextest','Testindex'].each do | this_class |
#      it_behaves_like 'basic class properties' , this_class
#    end
#  end
  context "Create a new document" do
    before( :all ) do 
      @db.create_class 'working_class' 
    end

    it "new document"  do
      n =  WorkingClass.new w_att: 'Attribute' 
      expect( n ).to be_a WorkingClass
      expect( n.w_att ).to eq 'Attribute'
      expect( n.rid.rid? ).to be_falsy

    end

    it "save new document" do
      n =  WorkingClass.new w_att: 'Attribute' 
      n.save
      expect( n.rid.rid? ).to be_truthy
      n.w_att = "New_Attribute"
      expect{ n.save }.to change{ n.version }.by 1

    end
  end


  context "Add and modify documents"   do
    before( :all ) do
      @db.create_class "doc_class"
    end
		let( :obj ){ TestModel.create test: 45  }

    it "put some data into the class"  do
      (0..45).each{|x|  DocClass.create  test_cont: x  }
      expect( DocClass.count ).to eq 46
    end

    it "the database is empty before we start"  do
      expect( TestModel.all ).to be_empty
      expect( @db.get_documents  from: TestModel ).to be_empty
      expect( TestModel.count ).to be_zero
    end

    it "create a document"  do
      expect( obj.test ).to eq 45
      expect( obj ).to be_a  ActiveOrient::Model
      expect( ActiveOrient::Base.get_riid.values.detect{|x| x == obj}).to be_truthy
    end


    it "the document can be retrieved by all"  do
      all = TestModel.all
      expect(all).to be_a Array
      expect(all.size).to eq 1
      expect(all.first).to  be_a ActiveOrient::Model
      expect(all.first.test).to eq 45
    end

    it "the document can be retrieved by first" do
      expect( TestModel.first ).to be_a ActiveOrient::Model
      expect( TestModel.first.test ).to eq 45
    end
##### Method Missing [:to_ary] ---> Dokumente werden wahrscheinlich aus dem Cash genommen
    #und nicht von der Datenbank abgefragt
    it "the document can be updated"  do
      expect{ obj.update set: { test: 76, new_entry: "This is a new Entry" } }.to change{ obj.version }.by 1
      expect( obj.test ).to eq 76
      expect( obj.new_entry).to be_a String
    end

    it "various Properties can be added to the document" do
      aa = [ 1,4,'r', :r ]  
      ah = { :a => 'b', b: 2, c: :d } 
      eh = { "a" => "b" , "b" => 2, "c" => :d  }
      obj.update set: { a_array: aa  , a_hash: eh }   
      expect( obj.a_array ).to eq aa
      expect( obj.a_hash ).to eq  ah   # Hash-keys are always symbols!!
    end

    it "a value can be added to the array" do
      obj.update a_array: [1,4,'r',:r]
			obj.a_array << 56
      expect(obj.a_array).to eq [ 1,4,'r', :r, 56 ]

    end

    it "the document can be deleted"  do
			d =  TestModel.create test: 56  # does not work using obj
      expect{ d.delete }.to change { TestModel.count }.by -1
    end
  end #context

  context "ActiveRecord mimics"  do
		before(:all) do 
			@db.create_edge_class  'my_edge'
			@db.create_vertex_class  'my_node'
			TestModel.delete
			 TestModel.create_property :test, type: :integer,   index: :unique
			 expect( TestModel.indexes.first['fields'] ).to eq ["test"]
			(0..45).each{|x| TestModel.create  test: x  }
			@db.database_classes requery: true
		end
    it "fetch all documents into an Array" do
      all_documents = TestModel.all
      expect( all_documents ).to be_a Array 
      expect( all_documents ).to have_at_least(45).elements
      all_documents.each{|x| expect(x).to be_a ActiveOrient::Model }
    end

    it "get a set of documents queried by where"  do
      nr_23=  TestModel.where  test: 23
      expect( nr_23 ).to have(1).element
      expect( nr_23.first.test).to eq 23
    end
    it "datasets are unique only  on update"    do
      expect{ TestModel.upsert(  :where => { test: 45 }) }. not_to change { TestModel.count }
      expect{ TestModel.create  test: 45 }.not_to change { TestModel.count }
    end


    it "specific datasets can be manipulated" do
      expect( TestModel.where( 'test > 40' ) ).to have(5).elements
      expect( TestModel.update_all( set: { new_ds: 45 }, where: 'test > 40')).to eq 5
      expect( TestModel.where( new_ds: 45 ) ).to have(5).elements
    end

    it "specific datasets can be removed" do
      count= TestModel.update_all( set: { new_ds: 45 }, where: 'test > 40')
      expect( TestModel.remove(  :new_ds , where: {test: 42})).to eq 1
      expect( TestModel.where( new_ds: 45 ) ).to have( count -1 ).elements
    end

    it "creates an edge between two vertices"  do
      node_1 = TestModel.where( test: 45 ).first
      node_2 = TestModel.where( test: 2 ).first
      node_3 = TestModel.where( test: 16 ).first
      expect( node_1 ).to be_a V
      expect( node_2 ).to be_a V
      the_edge = MyEdge.create( attributes: { halbwertzeit: 655 },
					  from: node_1,
					    to: node_2  )
      expect( the_edge ).to be_a E
      expect( the_edge.in ).to eq node_2
      expect( the_edge.out ).to eq node_1

## this is omitted in favor of using contrains on the edge-class 
      # creation of a second edge with the same properties leads to  reusing the existent edge
#      the_edge2= E.create(
#		    attributes: { halbwertzeit: 655 },
#		    from: node_1,
#		    to:   node_2  )
#      expect( the_edge.rid ).to eq the_edge2.rid
      #      the_edge2= @myedge.create_edge(
      #			  attributes: { halbwertzeit: 46 },
      #			  from: in_e,
      #			  to:   in_e2  )
      expect( the_edge.out ).to eq node_1 ## hier wird ein Document zurück gegeben...
      expect( the_edge.in ).to eq node_2
      #      expect( the_edge2.out ).to eq in_e
      #      expect( the_edge2.in ).to eq in_e2
#      out_e =  TestModel.where(  test: 23  ).first
#      expect( out_e ).to eq node_1
#      expect( out_e.attributes).to include 'out_Myedge'
#      in_e = TestModel.where(  test: 15  ).first
      #      puts "--------------------------------"
      #      puts node_1.attributes.inspect
      #      expect( in_e.attributes).to include 'in_Myedge'
      #    expect( node_1.myedge).to have(1).item
      #    expect( node_1.myedge[0][:out].test).to eq 23
      #    expect( node_1.in_Myedge[0][:in].test).to eq  15
    end

    it "deletes an edge"  do
      the_edges =  E.all
      expect(the_edges.size).to  be >=1
      the_edges.each do |edge|
        edge.remove
      end
      expect(E.count).to  be_zero
    end

  end

	context "upsert returns a valid dataset" do
		before( :all ) { TestModel2.delete }    # erase any content from TestModel

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
				its( :version ){ is_expected.to be > 1 }
				its( :a ){ is_expected.to eq 6 }
			end
		end
	end
end
