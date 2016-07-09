require 'spec_helper'
####  Work in progress
#### specs are not working at all
if RUBY_PLATFORM == 'java'
describe ActiveOrient::API do
  # ao =   ActiveOrient::OrientDB.new 
  context 'connect' do
    it "connect with correct parameters" do
    @db =  ActiveOrient::Model.db # API.new  database: 'temp'
    expect(@db.db).to be_a  Java::ComOrientechnologiesOrientCoreDbDocument::ODatabaseDocumentTx
    end
    # TEST FAILS it seems, that its not possibile to catch java-errors from ruby
    #
   # it "conncet with wrong parameters" do
   #   ActiveOrient::API.default_server= { user: 'unknown', password: 'no' } 
   # DB =  ActiveOrient::API.new  database: 'temp'
   # expect(DB.db).to be_a  Java::ComOrientechnologiesOrientCoreDbDocument::ODatabaseDocumentTx
   # end
  end
  # ao.delete_database database: 'temp'
  context 'check working environment' do
  before(:all) do
    @oRD  = ActiveOrient::Model.orientdb # OrientDB.new database: 'temp', preallocate: false 
    @oDB =  ActiveOrient::Model.db # API.new  database: 'temp', preallocate: false
    ORD.delete_class 'model_test'
    TestModel = @oRD.open_class "model_test"
    @ecord = TestModel.create
  end
    it "each class has a api-reference" do
      @oRD.get_database_classes.each do |dbclass|
	expect( ActiveOrient::Model.get_model_class(dbclass).db ).to be_a ActiveOrient::API
	expect( ActiveOrient::Model.get_model_class(dbclass).db ).to eq @oDB 
      end
    end
    it "DB has appropiate classes" do
      expect(@oDB.database_classes.sort).to eq @oRD.database_classes.sort
    end
      
#    db_schema_classes = DB.db.metadata.schema.classes.to_a.map( &:name ).sort#.join(" : ")
#    ord_schema_classes = ORD.get_database_classes.sort#.join(' : ')
#    expect( db_schema_classes ).to eq ord_schema_classes
#  end
    #	expect( DB.

    it 'get metadata and schema' do

      @oRD.get_database_classes.each do |dbclass|
#	puts "dbclass: #{dbclass}"
	expect( @oDB.db.metadata.schema.classes.to_a.detect{|x| x.name == dbclass }).to be_truthy
#	puts "dbclass: #{dbclass}"
      end
    end
    it 'class_hierarchy returns the expected data' do
     o_c_h = @oRD.class_hierarchy
     d_c_h =  @oDB.class_hierarchy
     expect( @oRD.class_hierarchy.size).to eq @oDB.class_hierarchy.size
    # followup tests are nessesary, sort does not work on the array
    end
  end

  context 'work with classes' do
  before(:all) do
    @oRD  = ActiveOrient::Model.orientdb # OrientDB.new database: 'temp', preallocate: false 
    @oDB =  ActiveOrient::Model.db # API.new  database: 'temp', preallocate: false
    @testclass = :myTetClass
    @oDB.delete_class @testclass if @oDB.get_database_classes.include? @testclass.to_s
  end
  it "creation  of a class " do
    expect{ @oDB.create_class @testclass }.to change { @oDB.get_database_classes.size}.by 1
  end
  it "removal of a class" do
    expect{ @oDB.delete_class @testclass }.to change { @oDB.get_database_classes.size}.by -1
  end

  it "add properties to a class"  do
    @oDB.create_class @testclass
    @oDB.create_properties(@testclass,
			   con_id: {type: :integer},
			   details: {type: :link},
			    other_details: {type: :link_map, other_class: 'Contract'} ) do
			      { contract_idx: :notunique }
			  end
    expect(@oDB.get_properties(@testclass)[:properties]).to have(3).items
    index =  @oDB.db.get_class( @testclass ).indexes.first
    expect( index.name ).to eq 'contract_idx'
    expect( index.type ).to eq 'NOTUNIQUE'
    properties = @oDB.db.get_class( @testclass ).properties
    properties.each do  | p |
      case p.name 
      when 'con_id'
	expect( p.type.to_s ).to eq "INTEGER" 
      when 'details'
	expect(p.type.to_s ).to eq "LINK"
      else 'other_details'
	expect(p.type.to_s ).to eq "LINKMAP"
	expect(p.linked_class.name ).to eq "Contract"
      end

    end
  end

   ##  todo: add a test to verify the creation of an index


 end  # context

  context "create, update, fetch and delete a Record"  do
  before(:all) do
    @oRD  = ActiveOrient::Model.orientdb # OrientDB.new database: 'temp', preallocate: false 
    @oDB =  ActiveOrient::Model.db # API.new  database: 'temp', preallocate: false
    @testclass = :myTetClass
    @oDB.delete_class @testclass if @oDB.get_database_classes.include? @testclass.to_s
    @oDB.create_class @testclass
  end

  it "create a record" do
    test_class =  @oDB.db.get_class @testclass
puts ActiveOrient::Model.get_model_class(test_class.name)

    expect{ @new_record=  @oDB.create_record @testclass, attributes: { new_value: 56 } }.to change{  test_class.count }.by 1
    expect( @new_record ).to be_a  ActiveOrient::Model::MyTetClass
    expect( test_class.count ).to eq 1

  end

  it "insert different objects "  do
    test_class =  @oDB.db.get_class @testclass
    test_model =  ActiveOrient::Model.get_model_class(test_class.name)
    puts test_model.inspect

    # string
    record = test_model.create test_var: 'test_string'
    expect( record.test_var ).to eq 'test_string'
    expect( record.test_var ).to be_a String

    # 
    record = test_model.create test_var: 25
    expect( record.test_var ).to eq 25
    expect( record.test_var ).to be_a Fixnum
    
    record = test_model.create test_var: 25.23
    expect( record.test_var ).to eq 25.23
    expect( record.test_var ).to be_a Float
    
    record = test_model.create test_var:  Date.today
    expect( record.test_var ).to be_a Date
#
    ts=    DB.get_record record.rid
    expect( ts.test_var ).to eq Date.today

  end
  end
end
end
