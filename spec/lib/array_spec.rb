require 'spec_helper'
####  Work in progress
#### specs are not working at all
describe OrientSupport::Array do
  before( :all ) do

   ao =   ActiveOrient::OrientDB.new 
   ao.delete_database database: 'ArrayTest'
    ORD  = ActiveOrient::OrientDB.new database: 'ArrayTest' 
    ORD.delete_class 'model_test'
    TestModel = ORD.open_class "model_test"
    @ecord = TestModel.create
  end

  context "check isolated" do
    let( :basic ) { OrientSupport::Array.new @ecord, 'test', 6, 5 }
    it { expect( basic ).to be_a OrientSupport::Array }

    it { expect( basic ).to have(3).items }


    it "change the value of an element" do
      expect{ basic[0]  =  "a new Value " }.to change{ basic.first }
      expect( basic ).to eq [ "a new Value ", 6, 5 ]
    end
  end


  context "verify a proper TestEnvironment" do
    it{ expect( TestModel.count ).to eq 1 }
    it{ expect( @ecord ).to be_a ActiveOrient::Model::ModelTest }
  end

  context "add and populate an Array" do
    before(:each){ @ecord.update set: { ll:  ['test', 5, 8 , 7988, "uzg"] } }

    it "initialize the Object"  do
      expect( @ecord.ll ).to be_a OrientSupport::Array
      expect( @ecord.ll.first ).to eq "test"
      expect( @ecord.ll[2] ).to eq 8
    end
    it "modify the Object"  do
      expect{ @ecord.add_item_to_property( :ll, 't') ; @ecord.reload! }.to change { @ecord.version }.by 1
      expect{ @ecord.ll << 78 }.to change { @ecord.ll.size }.by 1
      expect{ @ecord.reload! }.to change { @ecord.version }.by 1

      expect{ @ecord.ll.delete_at(2) }.to change { @ecord.ll.size }.by -1
      expect{ @ecord.ll.delete 'test' }.to change { @ecord.ll.size }.by -1
      expect{ @ecord.reload! }.to change { @ecord.version }.by 2
      expect do
        expect{ @ecord.ll.delete 7988, 'uzg' }.to change { @ecord.ll.size }.by( -2 )
	@ecord.reload!
      end.to change{  @ecord.version }.by 1
    end
    it "update the object"  do
      expect{ @ecord.ll[0]  =  "a new Value " }.to change{ @ecord.version }
      expect( @ecord.ll ).to eq [ "a new Value ", 5, 8 , 7988, 'uzg']

    end


    context "Work with arrays containing links" do
      before(:all) do
        ORD.delete_class  'Test_link_class'

        LinkClass = ORD.open_class 'Test_link_class'
        @new_record = TestModel.create ll: [ ]
        (1..9).each do |i|
          @new_record.ll << i
          @new_record.ll << LinkClass.create( att: "#{i} attribute" )
        end
      end

      it "verify the datastructure" do
        expect( @new_record.ll ).to have(18).items
        expect( @new_record.ll.first).to eq 1
        expect( @new_record.ll.at(1)).to eq LinkClass.first
        #      puts @new_record.ll.map{|y| y.is_a?( REST::Model )? y.att : y }.join(' ; ')
      end

      it "add and remove records" do
        expect{ @new_record.ll << LinkClass.create( new: "Neu" ) }.to change { @new_record.ll.size }.by 1
        expect{ @new_record.ll.delete  LinkClass.last }.to change { @new_record.ll.size }.by -1
        expect{ @new_record.ll.delete  9 }.to change { @new_record.ll.size }.by -1
        expect{ @new_record.ll.delete 19 }.not_to change { @new_record.ll.size }
        expect{ @new_record.ll.delete  1,8 }.to change { @new_record.ll.size }.by -2
        expect{ @new_record.ll.delete_if{|x| x.is_a?(Numeric)}}.to change {@new_record.ll.size }.by -6
        expect{ @new_record.ll.delete_if{|x| x.is_a?(ActiveOrient::Model) && x.att.to_i == 3}}.to change {@new_record.ll.size }.by -1
        expect{ @new_record.ll.delete_if{|x| x == LinkClass.first.rid}}.to change {@new_record.ll.size }.by -1
      end
    end
  end

  context 'work with multi dimensional Arrays' do
    let( :multi_array ){ a = [1,2,3];  b = [ :a, :b, :c ]; [ a, b ] }
    it 'intitialize' do
      new_record = TestModel.create ll: multi_array
      expect( new_record.ll ).to eq [[1, 2, 3], ["a", "b", "c"]]

    end

    it "use saved dataset for update" do
      dataset =  TestModel.create ll: []    # create schemaless property type embedded
      expect{ dataset.update set: {ll: multi_array  } }.to change{ dataset.version }
      # explicit reread the dataset
      data_set =  TestModel.all.last  # last does not work in Vers. 2.2
      expect( data_set.ll ).to eq [[1, 2, 3], ['a', 'b', 'c']]

    end

  end
  context 'work with subsets of the embedded array'  do
    before(:all) do
      ORD.delete_class  'Test_link_class'

      LinkClass = ORD.open_class 'Test_link_class'
      @new_record = TestModel.create ll: [ ]
      (1..99).each do |i|
        @new_record.ll << i
        @new_record.ll << LinkClass.create( att: "#{i} attribute" )
      end
    end

    #    it{ expect( @new_record.ll ).to have(198).items }

    it "get one element from the embedded array by index" do
      i = 40
      #	numeric_element =  @new_record.ll[i]
      linked_element = @new_record.ll[i+1]

      #          expect( numeric_element ).to be_a Numeric
      expect( linked_element ).to be_a LinkClass
    end

    it "get one element from the embedded array by condition" do
      expect(  @new_record.ll.find_all{|x| x.is_a?( ActiveOrient::Model)  &&  x.att == "30 attribute" }.pop ).to be_a LinkClass
      expect(  @new_record.ll.where( :att => "30 attribute" ).pop ).to be_a LinkClass
      # matches is broken in 2.2
      #linked_element =  @new_record.ll.where( "att matches  '\b3\b'" )a
      #  like + % does not work in REST environment
       #      linked_element =  @new_record.ll.where( "att like '3%'" )
             #linked_element =  @new_record.ll.where( "att like '3\u0025'" )
      #puts linked_element.inspect
      # raises an Error: 505 HTTP Version Not Supported
    end



  end

  context 'work with a hard-coded linkmap' do
    before(:all) do
      ORD.delete_class  'Test_link_class'
      ORD.delete_class  'Test_base_class'

      BaseClass = ORD.open_class 'Test_base_class'
      LinkClass = ORD.open_class 'Test_link_class'
      BaseClass.create_linkset  'aLinkSet',  LinkClass
      @new_record = BaseClass.create  aLinkSet: []
      (1..9).each do |i|
        @new_record.aLinkSet << LinkClass.create( att: "#{i} attribute" )
      end
    end

    it "verify the datastructure" do
      #	puts @new_record.aLinkSet.map{|y| y.is_a?( ActiveOrient::Model )? y.att : y }.join(' ; ')
      expect( @new_record.aLinkSet ).to have(9).items
      expect( @new_record.aLinkSet.at(0)).to eq LinkClass.first
    end
    it "add and remove records" do
      expect{ @new_record.aLinkSet << LinkClass.create( new: "Neu" ) }.to change { @new_record.aLinkSet.size }.by 1
      #	expect{ @new_record.aLinkSet.delete  LinkClass.last }.to change { @new_record.aLinkSet.size }.by -1
      # gives an Error - its not possible to mix links with other objects
     	expect{ @record_with_6 =  @new_record.aLinkSet <<   6 }.to change { @new_record.aLinkSet.size }.by 1
	puts @record_with_6.inspect
	### this fails!!
#     	expect{ @new_record.aLinkSet.delete  @record_with_6 }.to change { @new_record.aLinkSet.size }.by -1
      expect{ @new_record.aLinkSet.delete 19 }.not_to change { @new_record.aLinkSet.size }
      expect{ @new_record.aLinkSet.delete  LinkClass.last, LinkClass.first  }.to change { @new_record.aLinkSet.size }.by -2
      expect{ @new_record.aLinkSet.delete_if{|x| x == LinkClass.where( att: '5 attribute').pop.rid}}.to change {@new_record.aLinkSet.size }.by -1
    end

  end

#  context 'create an array and save it to a linkmap' do
#    before( :all ) do
#      AC= ORD.create_class  'array_class'
#      TLC= ORD.create_class  'this_link_class'
#      TLC.create_linkset 'this_set', AC
#      @item =  TLC.create this_set: [] 
#
#    end
#
#    set( :the_array ) do
#      a = OrientSupport::Array.new
#    end
#  end

end
