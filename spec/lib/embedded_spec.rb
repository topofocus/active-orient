require 'spec_helper'
require 'connect_helper'
require 'model_helper'

describe ActiveOrient::OrientDB do

  before( :all ) do
    @db = connect database: 'temp'
		@db.create_class :emb, :a_set, :a_list
		V.create_class :base 
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
      subject{  Base.query.where(  "a_set.currency containskey 'EUR'" ).execute }
      it { is_expected.to  be_a Array }
      it { is_expected.to have(1).item }
			it { expect(subject.first.a_set[:currency][:EUR]).to eq 4.32 }
      ### query for :home => something 
		end

  end


	context " embedd  records,"  do
		before(:all) do

			the_structure = [{ :key=>"WarrantValue", :value=>"8789", :currency=>"HKD"},
										{	:key=>"WhatIfPMEnabled", :value=>"true", :currency=>""},
										{ :key=>"TBillValue", :value=>"0", :currency=>"HKD" } ]


			@b =  Base.create( a_set: {}) 
			@the_hash= 	Hash[  the_structure.map{|x| [x[:key].underscore.to_sym, [x[:value], x[:currency] ] ] } ] 
			@b.a_set << @the_hash
		end
		context "the default embedded set" do
			subject { @b.a_set }
			it{ is_expected.to be_a OrientSupport::Hash }
			its(:size){ is_expected.to eq 3 }
			its(:keys){ is_expected.to include :what_if_pm_enabled  }
			its(:values){ is_expected.to include ["8789","HKD"]  }
			it "can be accessed by key" do
				expect( subject[:warrant_value].first ).to eq "8789"
			end
		end
		context "simple operations" do
			it " remove an entry " do
				b=  @b.reload!
				unless b.a_set.size ==3
					b.a_set << @the_hash
				end

				expect{ b.a_set.remove :warrant_value}.to change{ b.a_set.size }.by -1

			end


			it "add an entry"  do
				b = @b.reload!
				expect{ b.a_set << { :new_entry  => 45 }}.to change{ b.a_set.size }.by 1
			end


			it "store and delete some items" do
				b = @b.reload!
				expect{ b.a_set[:futures_value] =  56 }.to change{ b.a_set.size }.by 1
				expect{ b.a_set[:futures_value] =  "zu" }.not_to change{ b.a_set.size }
				expect{ b.a_set.delete_if{|x,y| y == "zu"} }.to change{ b.a_set.size }.by -1

			end
		end
	end
end

#  working: 
#  select from base where  a_set containskey '"currency' 
#  select from base where  a_set.currency containskey 'EUR'
#  not working
#  select from base where a_set.currency = "EUR"
#  select from base where "EUR" in a_set.currency
#
