require 'spec_helper'

describe 'Properties and Application of Hashes' do
  before( :all ) do

    # working-database: hc_database
    r =  ActiveOrient::OrientDB.new connect:false
    r.delete_database database: 'HashTest'

    @r = ActiveOrient::OrientDB.new database: 'HashTest'
    @r.delete_class 'model_test'
    TestModel = @r.open_class "model_test"
    @record = TestModel.create
  end

  #  context "check isolated", focus:true do
  #    let( :basic ) { OrientSupport::Hash.new @record, 'Go to Orient'}
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
    it{ expect( @record ).to be_a ActiveOrient::Model::ModelTest }
  end

  context "add and populate an Hash" do
    before(:all){ @record.update set: { ll:  { a:'test', b: 5, 8 => 57 , 'zu' => 7988 }  } }

    it "initialize the Object"  do
      expect( @record.ll ).to be_a HashWithIndifferentAccess
      expect( @record.ll.first ).to eq ["a","test"]
      expect( @record.ll[:b] ).to eq 5
      expect( @record.ll.keys ).to eq [ "a", "b", 8, "zu" ]
    end
    it "modify the Object" do
      #      expect{ @record.add_item_to_property :ll, 't' }.to change { @record.ll.size }.by 1
      expect do
        expect{ @record.ll[:z] = 78  }.to change { @record.ll.size }.by 1

        expect{ @record.ll.delete(8) }.to change { @record.ll.size }.by -1
        expect{ @record.ll.delete_if{|x,y| y==5} }.to change { @record.ll.size }.by -1
      end.not_to change{ @record.version }
    end
    it "update the object" , focus: true do
      expect{ @record.ll[0]  =  "a new Value "; @record.update }.to change{ @record.version }
      expect( @record.ll[0] ).to eq  "a new Value "
    end
  end

  context "a Hash with links " do

    before(:all) do
      LinkClass = @r.open_class 'hash_links'
      new_hash =  HashWithIndifferentAccess.new
      ( 1 .. 99 ).each do | i |
        new_hash[ "item_#{i}" ] = LinkClass.create( linked_item: i*i, value: "a value #{i+4}" )
      end
      @record.update set: { ll: new_hash }
    end

    it { expect( LinkClass.count ).to eq 99 }
    it { expect( @record.ll.size ).to eq 99 }
    it{  (1..99).each{|x| expect(@record.ll["item_#{x}"]).to be_a ActiveOrient::Model } }




  end

end
