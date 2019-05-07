
require 'spec_helper'
require 'connect_helper'
require 'model_helper'
describe ActiveOrient::OrientDB do
	before( :all ) do
		@db = connect database: 'temp'
		V.create_class :base, :first_list, :second_list, :log
		Base.create_property  :first_list,  type: :link_list, linked_class: FirstList 
		Base.create_property  :label, index: :unique 
		FirstList.create_property  :second_list , type: :list, linked_class: SecondList 
		if Base.count.zero?  # omit if structure is present

		(0 .. 9).each do | b |
			base_record = Base.create( label: b, first_list: [])
			(0..9 ).each do | c |
				list_record = FirstList.create( rubel: c , second_list: [])  
				list_record.second_list << (0..9).map{|n| SecondList.new( zobel: n ) }
				base_record.first_list <<  list_record
			end
			end  #c
		end
	end		  # before

#	after(:all){ @db.delete_database database: 'temp' }

		context 'FirstList' do
			subject{ FirstList }
			its(:count){ is_expected.to eq 100 }
		end
		context 'SecondList' do
			subject{ SecondList }
			its(:count){ is_expected.to be_zero }  # embedded linklist
			#its(:count){ is_expected.to eq 1000 }  # linklist
		end

  context "create and manage a 2 layer 1:n relation" do

		it "check base" do
			(0..9).each do | b |
				base =  Base.where( label: b ).first
				if RUBY_PLATFORM == 'java'
					expect( base.first_list ).to be_a OrientDB::RecordList
				else
					expect( base.first_list ).to be_a Array
				end
				expect( base.first_list ).to have(10).items
				base.first_list.each{|fl| expect( fl.second_list ).to have(10).items }
			end
		end
		
		it "query local structure" do
			Base.all.each do | b |
					puts "base: #{b.to_human}"
				(0..9).each do | c |
					  puts "First_List #{c}:: #{b.first_list[c].to_human}"
				(0..9).each do | d |
						  puts "Second_List: #{b.first_list[c].second_list.to_human}"
					  puts "c: #{c} ; d: #{d}"
					expect( b.first_list[c].second_list[d][:zobel] ).to eq d
				end
			end
			end

			q =  OrientSupport::OrientQuery.new.projection( 'first_list[5].second_list[9] as second_list')
																		 .where   label: 9 
			expect( q.to_s ).to eq 'select first_list[5].second_list[9] as second_list where label = 9 '
			# two different query approaches
			# the first attempt gets just the rid, the record is autoloaded (or taken from the cache)
			result1 = Base.query_database( q ){|x|  x[:second_list]}.first
			expect( result1).to be_a SecondList
			# the second attempt fetches the record directly
			q =  OrientSupport::OrientQuery.new.projection( 'expand( first_list[5].second_list[9])' )
			result2 = Base.query_database( q ).first

			expect( result2).to be_a SecondList

		end


    #    it "add a log entry to second list " do
    #    (0 .. 9 ).each do |y|
    #      log_entry = ActiveOrient::Model::Log.create :item => 'Entry no. #{y}'
    #	entry = base =  ActiveOrient::Model::Base.where( label: b)[y]
    #
    #

  end
  context "query-details" do
    it "generates a valid where query-string" do
      attributes = { uwe: 34 }
      expect( @db.compose_where( attributes ) ).to eq "where uwe = 34"
      attributes = { uwe: 34 , hans: :trz }
      expect( @db.compose_where( attributes ) ).to eq "where uwe = 34 and hans = 'trz'"
      attributes = { uwe: 34 , hans: 'trzit'}
      expect( @db.compose_where( attributes ) ).to eq "where uwe = 34 and hans = 'trzit'"
    end
  end
  context "document-handling"  do
    before(:all) do
      classname = "doc_klasse10"
      @db.create_class  :contract, :doc_klasse10  
			DocKlasse10.create_properties( 
				    symbol: { type: :string },
				    con_id: { type: :integer } ,
				    details: { type: :link, linkedClass: 'contract' }  )
    end


    it "create a single document"  do
      res=  DocKlasse10.create con_id: 345, symbol: 'EWQZ' 
      expect( res ).to be_a ActiveOrient::Model
      expect( res.con_id ).to eq 345
      expect( res.symbol ).to eq 'EWQZ'
      expect( res.version).to eq 1
    end


    it "create through upsert"  do
      res=  DocKlasse10.upsert  set: { a_new_property: 34 } , where: {con_id: 345, symbol: 'EWQZ' }
      expect( res ).to be_a DocKlasse10
      expect(res.a_new_property).to eq 34
      res2=  DocKlasse10.upsert  set: { a_new_property: 35 } , where: {con_id: 345 }
      expect( res2.a_new_property).to eq 35
      expect( res2).to eq res
    end

  end
end
