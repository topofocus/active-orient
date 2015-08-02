require 'spec_helper'

describe OrientSupport::Array do
  before( :all ) do

    # working-database: hc_database

    @r = ActiveOrient::OrientDB.new database: 'MyTest'
    @r.delete_class 'model_test'
    TestModel = @r.open_class "model_test" 
    @record = TestModel.create
  end

  context "check isolated" do
    it "initialize Object" do
      basic = OrientSupport::Array.new @record
      expect( basic ).to be_a OrientSupport::Array

    end
    it "add item o Object" do
      basic = OrientSupport::Array.new @record, 'test', 6, 5
      expect( basic ).to have(3).items
    
    end
  end


  context "verify a proper TestEnvironment" do
    it{ expect( TestModel.count ).to eq 1 }
    it{ expect( @record ).to be_a ActiveOrient::Model::ModelTest }
  end

  context "add and populate an Array" do
    it "initialize the Object" do
      @record.update set: { ll:  ['test', 5, 8 , 7988, "uzg"] }
      expect( @record.ll ).to be_a OrientSupport::Array
      expect( @record.ll.first ).to eq "test"
      expect( @record.ll[1] ).to eq 5
    end
    it "modify the Object" do
      expect{ @record.add_item_to_property :ll, 't' }.to change { @record.ll.size }.by 1
      expect{ @record.ll << 78 }.to change { @record.ll.size }.by 1

      expect{ @record.ll.delete_at(2) }.to change { @record.ll.size }.by -1
      expect{ @record.ll.delete 'test' }.to change { @record.ll.size }.by -1
      expect do
	expect{ @record.ll.delete 7988, 'uzg' }.to change { @record.ll.size }.by( -2 )
      end.to change{  @record.version }.by 1
    end


    context "Work with arrays containing links" do
      before(:all) do 
	@r.delete_class  'Test_link_class'

	LinkClass = @r.open_class 'Test_link_class'
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
	expect{ @new_record.ll.delete_if{|x| x == LinkClass.first.link}}.to change {@new_record.ll.size }.by -1
      end 
    end
  end

   context 'work with a hard-coded linkmap' do
      before(:all) do 
	@r.delete_class  'Test_link_class'
	@r.delete_class  'Test_base_class'

	BaseClass = @r.open_class 'Test_base_class'
	LinkClass = @r.open_class 'Test_link_class'
	BaseClass.create_linkset  'aLinkSet',  LinkClass
	@new_record = BaseClass.create  aLinkSet: []
	(1..9).each do |i|
	  @new_record.aLinkSet << LinkClass.create( att: "#{i} attribute" )
	end
      end

      it "verify the datastructure" do
	puts @new_record.aLinkSet.map{|y| y.is_a?( ActiveOrient::Model )? y.att : y }.join(' ; ')
	expect( @new_record.aLinkSet ).to have(9).items
	expect( @new_record.aLinkSet.at(0)).to eq LinkClass.first
      end
      it "add and remove records" do
	expect{ @new_record.aLinkSet << LinkClass.create( new: "Neu" ) }.to change { @new_record.aLinkSet.size }.by 1
#	expect{ @new_record.aLinkSet.delete  LinkClass.last }.to change { @new_record.aLinkSet.size }.by -1
	# gives an Error - its not possible to mix links with other objects
#	expect{ @new_record.aLinkSet.<<   9 }.to change { @new_record.aLinkSet.size }.by 1
	expect{ @new_record.aLinkSet.delete 19 }.not_to change { @new_record.aLinkSet.size }
	expect{ @new_record.aLinkSet.delete  LinkClass.last, LinkClass.first  }.to change { @new_record.aLinkSet.size }.by -2
	expect{ @new_record.aLinkSet.delete_if{|x| x == LinkClass.where( att: '5 attribute').pop.link}}.to change {@new_record.aLinkSet.size }.by -1
      end 

   end

end

