require 'spec_helper'
require 'connect_helper'
require 'rest_helper'

describe 'Properties and Application of Hashes' do
  before( :all ) do
    @db = connect database: 'temp'
    @db.create_class "test_model"
    @db.create_class 'link_class'
  end

	after(:all){ @db.delete_database database: 'temp' }
  #  context "check isolated", focus:true do
  #    let( :basic ) { OrientSupport::Hash.new @ecord, 'Go to Orient'}
  #    it { expect( basic ).to be_a OrientSupport:: Hash}
  #
  #    it { expect( basic ).to be_empty }
  #
  #
  #    it "add and change an element" do
  #      expect{ basic[ :test ] = 56 }.to change{ basic.size }
  #      expect{ basic[ :test ] = 'newtest' }.not_to change{ basic.size }
  #
  #    end
  ##    it "change the value of an element" do
  #      expect{ basic[0]  =  "a new Value " }.to change{ basic.first }
  #      expect( basic ).to eq [ "a new Value ", 6, 5 ]
  #    end

  #end



  context "add and populate an Hash" do
      let( :record ){  TestModel.create  ll:  { a:'test', b: 5, 8 => 57 , 'zu' => 7988 }  } 

    it "initialize the Object"  do
      expect( record.ll ).to be_a Hash
      expect( record.ll.first ).to eq ["a","test"]
      expect( record.ll[:b] ).to eq 5
      expect( record.ll.keys ).to eq [ "a", "b", 8, "zu" ]
    end
    it "modify the Object" , focus: true do
#      expect{ record.add_item_to_property :ll,  :a =>  :b }.to change { record.ll.size }.by 1
      expect do
        expect{ record.ll[:z] = 78  }.to change { record.ll.size }.by 1

        expect{ record.ll.delete(8) }.to change { record.ll.size }.by -1
        expect{ record.ll.delete_if{|x,y| y==5}; record.save }.to change { record.ll.size }.by -1
      end.to change{ record.version }.by 3
    end
    it "update the object" do
      expect{ record.ll[0]  =  "a new Value "}.to change{ record.version }
      expect( record.ll[0] ).to eq  "a new Value "
    end
  end

  context "a Hash with links "   do

    before(:all) do
      new_hash =  HashWithIndifferentAccess.new
      ( 1 .. 99 ).each do | i |
        new_hash[ "item_#{i}" ] = LinkClass.create( linked_item: i*i, value: "a value #{i+4}" )
      end
      @lnk = TestModel.create ll: new_hash 
    end

    it { expect( LinkClass.count ).to eq 99 }
    it { expect( @lnk.ll.size ).to eq 99 }
    it{  (1..99).each{|x| expect(@lnk.ll["item_#{x}"]).to be_a ActiveOrient::Model } }




  end

end
