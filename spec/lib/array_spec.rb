require 'spec_helper'
require 'model_helper'
require 'connect_helper'
#require 'rest_helper'
## works well with rest-api
describe OrientSupport::Array do
  before( :all ) do
    @db = connect database: 'temp'

    @db.create_class "test_model"
    @db.create_class 'link_class'
    @db.create_class 'base_class'
  end
	after(:all){ @db.delete_database database: 'temp' }

  let( :testrecord ){ TestModel.create }
  context "check isolated" do
    let( :basic ) { OrientSupport::Array.new work_on: testrecord, work_with: [ 'test', 6, 5 ]  }
    it { expect( basic ).to be_a OrientSupport::Array }

    it { expect( basic ).to have(3).items }


    it "change the value of an element" do
      expect{ basic[0]  =  "a new Value " }.to change{ basic.first }
      expect( basic ).to eq [ "a new Value ", 6, 5 ]
    end
  end



  context "add and populate an Array"  do
#    before(:each){ testrecord.update set: { ll:  ['test','test_2', 5, 8 , 7988, "uzg"] } }

		 subject { TestModel.create ll:  ['test','test_2', 5, 8 , 7988, "uzg"]  }
		 it_behaves_like 'a new record'
     its( :ll ) { is_expected.to  be_a Array }
     it{  expect( subject.ll.first ).to eq "test" }
     it{  expect( subject.ll[2] ).to eq 5 }

    it "modify the Object"  do
      expect{ subject.ll << 78 }.to change { subject.ll.size }.by 1
      expect{ subject.ll << 79 }.to change { subject.version }.by 1

      expect{ subject.ll.remove 'test_2' }.to change { subject.ll.size }.by -1
      expect do
        expect{ subject.ll.remove 7988, 'uzg', 788, 79  }.to change { subject.ll.size }.by( -3 )
#	puts testrecord.ll.inspect
#	puts testrecord.version
#	testrecord.reload!
      end.to change{  subject.version }.by 3
    end

    it "append to the array"   do
      subject.update set: { new_array: [24,25,26] }
      expect( subject.new_array ).to eq [24,25,26]
      
      expect{ subject.new_array << "rt" }.to change { subject.new_array.size }.by 1

      expect( subject.new_array ).to eq [24,25,26,'rt']


    end
    it "update the object"  do
      expect{ subject.ll[0]  =  "a new Value " }.to change{ subject.version }
      expect( subject.ll ).to eq [ "a new Value ", "test_2", 5, 8 , 7988, 'uzg']

    end


    context "Work with arrays containing links" , focus: true do
#
		  subject do	
				new_record = TestModel.create ll: [ ]
				lk = -> (z){ LinkClass.create att: "#{z} attribute" }
				(1..9).each{|i| new_record.ll << i ; new_record.ll <<  lk[i] } # LinkClass.create( att: "#{i} attribute" ) }			
				new_record.ll  # the subject
			end
				its(:size){ is_expected.to eq 18 }
				its(:first){ is_expected.to eq 1 }
				its(:last){ is_expected.to be_a LinkClass }
				

      it "add and remove records" do
#        new_record = subject << 9,1,8 
        expect{ subject << LinkClass.new( new: "Neu" ) }.to change { subject.size }.by 1

#        expect{ new_record.ll.remove  *LinkClass.where( new: 'Neu' ) }.to change { new_record.ll.size }.by -1
 #       expect{ new_record.ll.remove  9 }.to change { new_record.ll.size }.by -1
  #      expect{ new_record.ll.remove 19 }.not_to change { new_record.ll.size }
   #     expect{ new_record.ll.remove  1,8 }.to change { new_record.ll.size }.by -2
      end
    end
  end

  context 'work with multi dimensional Arrays' do
    let( :multi_array ){ a = [1,2,3];  b = [ :a, :b, :c ]; [ a, b ] }
    it 'intitialize' do
      new_record = TestModel.create ll: multi_array
      expect( new_record.ll ).to eq [[1, 2, 3], [:a, :b, :c]]

    end

    it "use saved dataset for update" do
      dataset =  TestModel.create ll: []    # create schemaless property type embedded
      expect{ dataset.update set: {ll: multi_array  } }.to change{ dataset.version }
      # explicit reread the dataset
      data_set =  TestModel.all.last  # last does not work in Vers. 2.2
      expect( data_set.ll ).to eq [[1, 2, 3], [:a, :b, :c]]

    end

  end
  context 'work with subsets of the embedded array'  do
    before(:all) do

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

      BaseClass.create_property 'aLinkSet',  type: :linkset, linked_class: LinkClass
      @new_record = BaseClass.create  aLinkSet: []
      (1..9).each do |i|
        @new_record.aLinkSet << LinkClass.create( att: "#{i} attribute" )
      end
    end

    it "verify the datastructure" do
      #	puts @new_record.aLinkSet.map{|y| y.is_a?( ActiveOrient::Model )? y.att : y }.join(' ; ')
      expect( @new_record.aLinkSet ).to have(9).items
      expect( @new_record.aLinkSet.at(0).att ).to eq "1 attribute"
    end
    it "add and remove records"  do 
      pending( "test for adding an existing link to the array: mixed arrays are not supported in 2.2" )
      expect{ @new_record.aLinkSet << LinkClass.create( new: "Neu" ) }.to change { @new_record.aLinkSet.size }.by 1
      	expect{ @new_record.aLinkSet.delete  LinkClass.last }.to change { @new_record.aLinkSet.size }.by -1
      # gives an Error - its not possible to mix links with other objects
     	expect{ @new_record.aLinkSet <<   6 }.not_to change { @new_record.aLinkSet.size }
	### this fails!!
#     	expect{ @new_record.aLinkSet.delete  @record_with_6 }.to change { @new_record.aLinkSet.size }.by -1
      expect{ @new_record.aLinkSet.delete 19 }.not_to change { @new_record.aLinkSet.size }
      expect{ @new_record.aLinkSet.delete  @new_record.aLinkSet[2], @new_record.aLinkSet[3] }.to change { @new_record.aLinkSet.size }.by -2
      expect{ @new_record.aLinkSet.delete_if{|x| LinkClass.where( att: '5 attribute').include?(x)} }.to change {@new_record.aLinkSet.size }.by -1
    end

  end


#  context 'create an array and save it to a linkmap' do
#    before( :all ) do
#      AC= @db.create_class  'array_class'
#      TLC= @db.create_class  'this_link_class'
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
