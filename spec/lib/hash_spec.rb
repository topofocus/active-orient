require 'spec_helper'

describe 'Properties and Application of Hashes' do
  before( :all ) do
#    ORD = ActiveOrient::OrientDB.new database: 'HashTest'
    ORD.delete_class 'model_test'
    TestModel = ORD.open_class "model_test"
    @ecord = TestModel.create
  end

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


  context "verify a proper TestEnvironment" do
    it{ expect( TestModel.count ).to eq 1 }
    it{ expect( @ecord ).to be_a ActiveOrient::Model::ModelTest }
  end

  context "add and populate an Hash" do
    before(:all){ @ecord.update set: { ll:  { a:'test', b: 5, 8 => 57 , 'zu' => 7988 }  } }

    it "initialize the Object"  do
      expect( @ecord.ll ).to be_a HashWithIndifferentAccess
      expect( @ecord.ll.first ).to eq ["a","test"]
      expect( @ecord.ll[:b] ).to eq 5
      expect( @ecord.ll.keys ).to eq [ "a", "b", 8, "zu" ]
    end
    it "modify the Object" do
      #      expect{ @ecord.add_item_to_property :ll, 't' }.to change { @ecord.ll.size }.by 1
      expect do
        expect{ @ecord.ll[:z] = 78  }.to change { @ecord.ll.size }.by 1

        expect{ @ecord.ll.delete(8) }.to change { @ecord.ll.size }.by -1
        expect{ @ecord.ll.delete_if{|x,y| y==5} }.to change { @ecord.ll.size }.by -1
      end.not_to change{ @ecord.version }
    end
    it "update the object"  do
      expect{ @ecord.ll[0]  =  "a new Value "; @ecord.update }.to change{ @ecord.version }
      expect( @ecord.ll[0] ).to eq  "a new Value "
    end
  end

  context "a Hash with links " do

    before(:all) do
      ORD.delete_class 'hash_links'
      LinkClass = ORD.open_class 'hash_links'
      new_hash =  HashWithIndifferentAccess.new
      ( 1 .. 99 ).each do | i |
        new_hash[ "item_#{i}" ] = LinkClass.create( linked_item: i*i, value: "a value #{i+4}" )
      end
      @ecord.update set: { ll: new_hash }
    end

    it { expect( LinkClass.count ).to eq 99 }
    it { expect( @ecord.ll.size ).to eq 99 }
    it{  (1..99).each{|x| expect(@ecord.ll["item_#{x}"]).to be_a ActiveOrient::Model } }




  end

end
