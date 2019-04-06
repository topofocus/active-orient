require 'spec_helper'
require 'connect_helper'
require 'model_helper'

describe ActiveOrient::Model do
  before( :all ) do
    @db = connect database: 'temp'
    @db.create_class( :test_index1,  :test_index2,  :test_index3 , :test_index4 ) 
    @db.create_vertex_class :industry
  end
	after(:all){ @db.delete_database database: 'temp' }

  context "add properties and indexes"  do

    before(:all) do
    end
    it "create a single property"  do

      TestIndex1.create_property( :Test, type: :string ) 

      expect( TestIndex1.properties[:properties].size ).to eq 1
      expect( TestIndex1.indexes ).to be_nil
    end
    it "create manualy properties and indices" do
      TestIndex2.create_property( :Test, type: :string ) 
      TestIndex2.create_index :testindex, on: :Test
      expect( TestIndex2.indexes ).to have(1).item
      ## this test fails if no index is preset before the condition ist fired.
      #  (get_properties is nil and size is not defined for nilclass.)
      expect { TestIndex2.create_property( :Facility, type: 'integer' ) }.to change { TestIndex2.properties[:properties].size }.by 1

      expect{ TestIndex2.create_index :facilindex, on: :Facility }.to  change { TestIndex2.properties[:indexes].size }.by 1
    end
# indices are definded on DB-Level and have to have unique names
    it "create a single property with a manual index" do
      TestIndex3.create_property( :Test, type: 'string')  {{ test_indes: :unique}} 

      expect( TestIndex3.properties[:properties] ).to have(1).item
      expect( TestIndex3.indexes ).to have(1).item
    end
    it "create several  properties with a composite index"  do
      count= TestIndex4.create_properties( test:  {type: :integer},
					   symbol: { type: :string },
					   industries: { type: 'LINKMAP', linked_class: 'industry' }   ) do
					    { sumindex: :unique }
					  end
      #expect( count ).to eq 3  # three properties
      expect( TestIndex4.properties[:properties] ).to have(3).items
      expect( TestIndex4.properties[:indexes] ).to have(1).item
      expect{ @db.create_index TestIndex4, name: :facil4index, on: :symbol }.to  change { TestIndex4.properties[:indexes].size }.by 1
    end
  end   ## properties 
end
