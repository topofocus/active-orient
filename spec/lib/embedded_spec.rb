require 'spec_helper'
require 'rest_helper'

describe ActiveOrient::OrientDB do

  before( :all ) do
    reset_database

      ORD.create_class "V","E"
      ORD.create_class :emb, :a_set, :a_list
      ORD.create_vertex_class :base 
      Base.create_property  :a_list,  type: :linklist, linkedClass: :a_list 
      Base.create_property  :label, type: :string, index: :unique 
      Base.create_property  :a_set, type: :embeddedMap
  end

  context "work on the generated schema of base" do
    it "insert an embedded map" do
    Base.create a_set: { home: 'test' }, label: 'Test1'
    expect( Base.count).to eq 1
    expect( Base.where(label: 'Test1').first.a_set ).to eq  "home" => 'test'
    expect( Base.where(label: 'Test1').first.a_set[:home] ).to eq   'test'
    Base.create a_set: { home: 'test4', currency: { 'EUR' => 4.32} }, label: 'Test4'
    expect(Base.last.a_set[:currency][:EUR]).to eq 4.32
    end

    it "query for an embedded map" do
      ### query for :currency => {"EUR" => something }
      qr=  Base.custom_where(  "a_set.currency containskey 'EUR'" )
      expect( qr ).to be_a Array
      expect( qr ).to have(1).item
      expect( qr ).to eq Base.where label: 'Test4'
      expect(qr.first.a_set[:currency][:EUR]).to eq 4.32
      ### query for :home => something 
      qr=  Base.custom_where(  "a_set.home = 'test4'" )
      expect(qr.first.a_set[:currency][:EUR]).to eq 4.32
    end

    it "update and extend the map " do
      qr=  Base.custom_where(  "a_set.currency containskey 'EUR'" )
      z= ORD.execute{ " update #{qr.first.rrid} set a_set.OptionMarketValue= { \"value\": 70 , \"currency\":  \"USD\" }" }
				expect{  }
      z= ORD.execute{ " update #{qr.first.rrid} set a_set.StockmarketValue = { \"value\": 500 , \"currency\":  \"EUR\" }" }
      puts z.inspect
      qr.reload!
      puts qr.inspect

    end
  end
end

#  working: 
#  select from base where  a_set containskey 'currency' 
#  select from base where  a_set.currency containskey 'EUR'
#  not working
#  select from base where a_set.currency = "EUR"
#  select from base where "EUR" in a_set.currency
#
