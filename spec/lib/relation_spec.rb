require 'spec_helper'
require 'rest_helper'

describe ActiveOrient::OrientDB do

  before( :all ) do
    reset_database
  end

  context "create and manage a 2 layer 1:n relation" do
    before(:all) do
      ORD.create_classes([:base, :first_list, :second_list ]){ "V" }
      ORD.create_property :base, :first_list,  type: :linklist, linkedClass: :first_list 
      ORD.create_property :base, :label, index: :unique 
      ORD.create_property :first_list,  :second_list , type: :linklist, linkedClass: :second_list 
      ORD.create_vertex_class :log
      if ActiveOrient::Model::Base.count.zero?  # omit if structure is present
	(0 .. 9).each do | b |
	  base= ActiveOrient::Model::Base.create label: b, first_list: []
	  base.add_item_to_property :first_list do 
	    (0 .. 9).map do | f |
	      first = ActiveOrient::Model::FirstList.create label: f, second_list: []
	      #	    base.add_item_to_property :first_list , first
	      first.add_item_to_property :second_list do
		(0 .. 9).map{| s |  ActiveOrient::Model::SecondList.create label: s }
	      end    # add item  second_list
	    end      # 0..9 -> f
	  end        # add item  first_list
	end	   # 0..9 -> b
      end		   # branch 
    end		  # before

    it "check base"  do
      (0..9).each do | b |
	base =  ActiveOrient::Model::Base.where( label: b)
	expect( base).to be_a Array
	expect( base.size ).to eq 1
	base= base.first
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
      sleep 2
      ActiveOrient::Model::Base.all.each do | base |
	puts "base: #{base.to_human}"
	(0 ..9 ).each do | c |
	  puts "First_List: #{base.first_list[c].to_human}"
	(0 .. 9).each do | d |
	  puts "c: #{c} ; d: #{d}"
	  expect( base.first_list[c].second_list[d].label ).to eq d
	end
      end
      end

      q =  OrientSupport::OrientQuery.new  from: :base
      q.projection << 'first_list[5].second_list[9] as second_list'
      q.where << { label: 9 }
      expect( q.to_s ).to eq 'select first_list[5].second_list[9] as second_list from base where label = 9 '
      # two different query approaches
      # the first attempt gets just the rid, the record is autoloaded (or taken from the cache)
      result1 = ActiveOrient::Model::Base.query_database( q ).first
      expect( result1.second_list).to be_a ActiveOrient::Model::SecondList
      q =  OrientSupport::OrientQuery.new  from: :base
      # the second attempt fetches the record directly
      q.projection << 'expand( first_list[5].second_list[9])'
      result2 = ActiveOrient::Model::Base.query_database( q ).first
      expect( result2).to be_a ActiveOrient::Model::SecondList

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
      expect( ORD.compose_where( attributes ) ).to eq "where uwe = 34"
      attributes = { uwe: 34 , hans: :trz }
      expect( ORD.compose_where( attributes ) ).to eq "where uwe = 34 and hans = 'trz'"
      attributes = { uwe: 34 , hans: 'trzit'}
      expect( ORD.compose_where( attributes ) ).to eq "where uwe = 34 and hans = 'trzit'"
    end
  end
  context "document-handling"   do
    before(:all) do
      classname = "Documebntklasse10"
      ORD.delete_class classname
      ORDest_class = ORD.create_class classname
      ORD.create_class 'Contract'
      ORD.create_properties( ORDest_class,
			    { symbol: { type: :string },
	 con_id: { type: :integer } ,
	 details: { type: :link, linkedClass: 'Contract' } } )


    end
    #          after(:all){  ORD.delete_class ORDest_class }


    it "create a single document"  do
      res=  ORD.create_document ORDest_class , attributes: {con_id: 345, symbol: 'EWQZ' }
      expect( res ).to be_a ActiveOrient::Model
      expect( res.con_id ).to eq 345
      expect( res.symbol ).to eq 'EWQZ'
      expect( res.version).to eq 1
    end


    it "create through create_or_update"  do
      res=  ORD.upsert   ORDest_class , set: { a_new_property: 34 } , where: {con_id: 345, symbol: 'EWQZ' }
      expect( res ).to be_a ORDest_class
      expect(res.a_new_property).to eq 34
      res2= ORD.upsert  ORDest_class , set: { a_new_property: 35 } , where: {con_id: 345 }
      expect( res2.a_new_property).to eq 35
      expect( res2.version).to eq res.version+1
    end

    it   "uses create_or_update and a block on an exiting document" do  ##update funktioniert nicht!!
      expect do
	ORDes=  ORD.create_or_update_document( ORDest_class ,
					      set: { a_new_property: 36 } ,
					      where: {con_id: 345, symbol: 'EWQZ' } ) do
						{ another_wired_property: "No time for tango" }
					      end
      end.not_to change{ ORDest_class.count }

      ###check 
      expect( ORDes.a_new_property).to eq 36
      ###check
      expect( ORDes.attributes.keys ).not_to include 'another_wired_property'  ## block is not executed, because its not a new document

    end
    it   "uses create_or_update and a block on a new document" do
      expect do
	@ord  = ORD.create_or_update_document( ORDest_class ,
					      set: { a_new_property: 37 } ,
					      where: {con_id: 345, symbol: 'EWQrGZ' }) do
						{ another_wired_property: "No time for tango" }
					      end
      end.to change{ ORDest_class.count }.by 1

      expect( @ord.a_new_property).to eq 37
      expect( @ord.attributes.keys ).to include 'another_wired_property'  ## block is executed, because its a new document

    end

    it "update strange text"  do  # from the orientdb group
      strange_text = { strange_text: "'@type':'d','a':'some \\ text'"}

      res=  ORD.create_or_update_document   ORDest_class , set: { a_new_property: 36 } , where: {con_id: 346, symbol: 'EWQrGZ' } do
	strange_text
      end
      expect( res.strange_text ).to eq strange_text[:strange_text]
      document_from_db =  ORD.get_document res.rid
      expect( document_from_db.strange_text ).to eq strange_text[:strange_text]
    end
    it "read that document" do
      r=  ORD.create_document  ORDest_class, attributes: { con_id: 343, symbol: 'EWTZ' }
      expect( r.class ).to eq ORDest_class
      res = ORD.get_documents  from: ORDest_class, where: { con_id: 343, symbol: 'EWTZ' }
      expect(res.first.symbol).to eq r.symbol
      expect(res.first.version).to eq  r.version

    end

    it "count datasets in class" do
      r =  ORD.count_documents  from: ORDest_class
      expect( r ).to eq  4
    end

    it "updates that document"   do
      r=  ORD.create_document  ORDest_class, attributes: { con_id: 340, symbol: 'EWZ' }
      rr =  ORD.update_documents  ORDest_class,
	set: { :symbol => 'TWR' },
	where: { con_id: 340 }

      res = ORD.get_documents   from: ORDest_class, where:{ con_id: 340 }
      expect( res.size ).to eq 1
      expect( res.first['symbol']).to eq 'TWR'

    end
    it "deletes that document" do
      ORD.create_document  ORDest_class , attributes: { con_id: 3410, symbol: 'EAZ' }
      r=  ORD.delete_documents  ORDest_class , where: { con_id: 3410 }
      res = ORD.get_documents  from: ORDest_class, where: { con_id: 3410 }
      expect(r.size).to eq 1
      expect(res).to be_empty
    end
  end
end
