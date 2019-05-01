
require 'spec_helper'
require 'connect_helper'
#require 'model_helper'
#require 'active_support'


describe ActiveOrient::Model do
    before(:all) do 
      @db = connect database: 'temp'
			@db.create_vertex_class "test_model"
  end

  context "simple adhoc properties"  do

		it "check basic class apperarence " do
			[[ :a_integer, 100, Integer ], 
		[ :a_string, 'string', String ], 
		[ :a_symbol, :symbol, Symbol ], 
		[ :a_float, 45.98923, Float] ,
		[ :an_array, [:a,:b,:c], Array,],
			[ :a_hash , { :a => 'f', b: 24, c: [1,'b', :c] , d: { f: 34 }}, Hash ] 
			].each do | a |
				record =  TestModel.create a.first => a.at(1)
				## test fails for array in jruby-mode , as it converts arrays into :OTrackedList: 
				expect( record ).to be_a TestModel
				expect( record.send a.first ).to be_a a.last #unless record.document.present?
				## test fails for hash, as HashWithIndifferentAccess returns Symbols as String
				# puts record.inspect
				# puts record[a.first].inspect
				expect( record[a.first]).to eq a[1] # unless record.document.present?
			end
		end
		#    subject { TestModel.create a_integer: 100 }
		#   its( :a_integer )  { is_expected.to be_a Fixnum }
	end

  context "simple operations" do
    let( :record ) { TestModel.create a_integer: 5, 
				      a_string: 'test',
				      a_symbol: :TestSymbol,
				      an_array: [:a, :b, :c],
							an_hash: { a: 'eins', b: 'zwei', c: 4 },
				      a_float: 245.5  }
    it "arithmetiric on simple classes" do
      expect{ record.a_integer += 5 }.to change {record.a_integer}.by 5
    # it even changes the class of a record-cell
      expect{ record.a_integer = "trzr"; record.save }.to change{ record.a_integer}
      expect(record.a_integer).to eq "trzr"
      
    end
    it "some string operations" do
      expect{ record.a_string.capitalize!; record.save }.to change {record.a_string}
      modified_record= @db.get_record record.rid  
      expect( modified_record.a_string ).to eq 'Test'
      expect{ record.a_string.delete!('es'); record.save }.to change {record.a_string}
      modified_record= @db.get_record record.rid  
      expect( modified_record.a_string ).to eq 'Tt'
    end

    it "array-operations"  do
      expect{ record.an_array << 2 }.to change{ record.an_array.size }.by 1
      expect( record.an_array.to_a).to eq [:a, :b, :c, 2 ]
      

    
    end

		context "update record " do
			before( :all) do
				@the_record = TestModel.create a_string: "test" 
			end

			it "status quo" do
				expect( @the_record.a_string ).to eq "test"
				expect( @the_record.version ).to eq 1
			end

			it " update the record" do
				@the_record.update a_string: "test2"
				expect( @the_record.a_string ).to eq "test2"
				expect( @the_record.version ).to eq 2
			end

			it "fringe update" do
				x= @db.execute { "update #{@the_record.rrid} set a_string =  'test5' "}
				expect( x).to eq [count: 1]

				expect( @the_record.a_string ).to eq "test2"
				expect( @the_record.version ).to eq 2

				@the_record.reload!
				expect( @the_record.a_string ).to eq "test5"
				expect( @the_record.version ).to eq 3
			end
		end



	end


end
