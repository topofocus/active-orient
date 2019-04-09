require 'spec_helper'
require 'connect_helper'
require 'model_helper'

describe ActiveOrient::OrientDB do

  before( :all ) do
    @db = connect database: 'temp'
		@db.create_class :emb, :a_set, :a_list
		@db.create_vertex_class :base 
      Base.create_property  :a_list,  type: :list, linked_class: :a_list 
      Base.create_property  :label, type: :string, index: :unique 
      Base.create_property  :a_set, type: :map
  end
	after(:all){ @db.delete_database database: 'temp' }

  context "work on the generated schema of base" do
    it "insert an embedded map" do
    Base.create a_set: { home: 'test' }, label: 'Test1'
    expect( Base.count ).to eq 1
		expect( Base.first.a_set).to be_a OrientSupport::Hash 
    expect( Base.where(label: 'Test1').first.a_set ).to eq  home: 'test'
    expect( Base.where(label: 'Test1').first.a_set[:home] ).to eq   'test'
    Base.create a_set: { home: 'test4', currency: { 'EUR' => 4.32} }, label: 'Test4'
    expect(Base.last.a_set[:currency][:EUR]).to eq 4.32
    end

    context "query for an embedded map" do

      ### query for :currency => {"EUR" => something }
      subject{  Base.custom_where(  "a_set.currency containskey 'EUR'" ) }
      it { is_expected.to  be_a Array }
      it { is_expected.to have(1).item }
      it { is_expected.to eq Base.where( label: 'Test4') }
			it { expect(subject.first.a_set[:currency][:EUR]).to eq 4.32 }
      ### query for :home => something 
		end

#    it "update and extend the map " do
#      qr=  Base.custom_where(  "a_set.currency containskey 'EUR'" )
#			qr.update set a_set: 
#      z= @db.execute{ " update #{qr.first.rrid} set a_set.OptionMarketValue= { \"value\": 70 , \"currency\":  \"USD\" }" }
#				expect{  }
#      z= @db.execute{ " update #{qr.first.rrid} set a_set.StockmarketValue = { \"value\": 500 , \"currency\":  \"EUR\" }" }
#      puts z.inspect
#      qr.reload!
#      puts qr.inspect

#    end
  end


	context " embedd list records" do
		it ""
	end
end

#  working: 
#  select from base where  a_set containskey 'currency' 
#  select from base where  a_set.currency containskey 'EUR'
#  not working
#  select from base where a_set.currency = "EUR"
#  select from base where "EUR" in a_set.currency
#
