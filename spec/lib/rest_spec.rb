
require 'spec_helper'
require 'rest_helper'


shared_examples_for 'a valid Class' do

end
describe ActiveOrient::OrientDB do

  #  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }

  before( :all ) do
   ao =   ActiveOrient::OrientDB.new 
   ao.delete_database database: 'RestTest'
   ORD  =  ActiveOrient::OrientDB.new database: 'RestTest' 
#   @database_name = 'RestTest'
  end


  context "check private methods", :private do
    ## uris are  not used any more
#    it 'simple_uris' do
#      expect( ORD.property_uri('test')).to eq "property/#{@database_name}/test"
#      expect( ORD.command_sql_uri ).to eq "command/#{@database_name}/sql/"
#      expect( ORD.query_sql_uri ).to eq "query/#{@database_name}/sql/"
#      expect( ORD.database_uri ).to eq "database/#{@database_name}"
#      expect( ORD.document_uri ).to eq "document/#{@database_name}"
#      expect( ORD.class_uri ).to eq "class/#{@database_name}"
#      expect( ORD.class_uri {'test'} ).to eq "class/#{@database_name}/test"
#
#    end
#
    context  "translate property_hash"  do
      it "simple property" do
        ph= { :type => :string }
        field = 't'
        expect( ORD.translate_property_hash field , ph ).to eq  field => {:propertyType=>"STRING"}
      end
      it "simple property with linked_class" do
        ORD.open_class :Contract
        ph= { :type => :link, linked_class: 'Contract' }
        field = 't'
        expect( ORD.translate_property_hash field , ph ).to eq  field => {:propertyType=>"LINK", :linkedClass=>"Contract"}
      end

      it 'primitive property definition' do
        ph= {:propertyType=>"STRING" }
        field = 't'
        expect( ORD.translate_property_hash field , ph ).to eq  field => {:propertyType=>"STRING"}
        ph= {:propertyType=> :string}
        expect( ORD.translate_property_hash field , ph ).to eq  field => {:propertyType=>"STRING"}
        ph= {:propertyType=> 'string'}
        expect( ORD.translate_property_hash field , ph ).to eq  field => {:propertyType=>"STRING"}
      end
      it 'primitive property definition with linked_class' do
        ph= {:propertyType=>"STRING", linked_class: :Contract }
        field = 't'
        expect( ORD.translate_property_hash field , ph ).to eq  field => {:propertyType=>"STRING", :linkedClass=>"Contract"}
        ph= {:propertyType=> :string, linkedClass: :Contract }
        expect( ORD.translate_property_hash field , ph ).to eq  field => {:propertyType=>"STRING", :linkedClass=>"Contract" }
      end
    end
  end
  context "establish a basic-auth ressource"   do
    it "connect " do
      expect( ORD.get_resource ).to be_a RestClient::Resource
      expect( ORD.connect ).to be_truthy
    end
  end


  describe "handle Properties at Class-Level"  do
    before(:all) do
      ORD.create_classes [ :Contract, :Exchange, 'property' ]
    end
#    before(:each){ ActiveOrient::Model::Property.delete_class; 	Property = ORD.create_class 'property' }
    before(:each){ ORD.delete_class 'property'; ORD.create_class 'property' }
    # after(:all){ ORD.delete_class 'property' }
    let( :predefined_property ) do
      rp = ORD.create_properties( ActiveOrient::Model::Property,
				 symbol: { propertyType: 'STRING' },
				 con_id: { propertyType: 'INTEGER' } ,
				 exchanges: { propertyType: 'LINKLIST', linkedClass: :Exchange } ,
				 details: { propertyType: 'LINK', linkedClass: :Contract },
				 date: { propertyType: 'DATE' }
				)
    end

    it "define some Properties on class Property" do

      ## count the number of defined properties 
      expect( predefined_property ).to eq 5
      rp= ORD.get_class_properties(  ActiveOrient::Model::Property )['properties']

      [ :con_id, :symbol, :details, :exchanges, :date ].each do |f|
	expect( rp.detect{|x| x['name']== f.to_s}  ).to be_truthy
      end
      expect( rp.detect{|x| x['name']== 'property'} ).to be_falsy
    end
    it "define property with automatic index"   do
      predefined_property
      c = ORD.open_class :contract_detail
      ORD.create_property( c, :con_id, type: :integer) { :unique }
      expect( ORD.get_class_properties(c)['indexes'] ).to have(1).item
      expect( ORD.get_class_properties(c)['indexes'].first).to eq(
	{	"name"=>"contract_detail.con_id", "type"=>"UNIQUE", "fields"=>["con_id"] } )
    end

    it "define a property with manual index" do
      predefined_property
      ORD.delete_class :contract
      contracts = ORD.open_class :contract
      industries = ORD.open_class :industry
      rp = ORD.create_properties( contracts,
				 { symbol: { type: :string },
       con_id: { type: :integer } ,
       industry: { type: :link, linkedClass: 'Industry' }  } ) do
	 { test_ind: :unique }
       end
       expect( ORD.get_class_properties(contracts)['indexes'] ).to have(1).item
       expect( ORD.get_class_properties(contracts)['indexes'].first).to eq(
	 {	"name"	  =>  "test_ind", 
		"type"	  =>  "UNIQUE", 
		"fields"  =>  ["symbol", "con_id", "industry"] } )
    end

    it "add a dataset"   do
      ## without predefined property the test fails because the date is recognized as string.
      predefined_property
      industries = ORD.open_class :industry
      linked_record = ActiveOrient::Model::Industry.create_record attributes:{ label: 'TestIndustry' }
      expect{ ActiveOrient::Model::Property.update_or_create where: { con_id: 12345 }, 
					set: { industry: linked_record.rid, 
					date: Date.parse( "2011-04-04") } 
	    }.to change{ ActiveOrient::Model::Property.count }.by 1

      ds = ActiveOrient::Model::Property.where con_id: 12345
      expect( ds ).to be_a Array
      expect( ds.first ).to be_a ActiveOrient::Model::Property
      expect( ds.first.con_id ).to eq 12345
      expect( ds.first.industry ).to eq linked_record
      expect( ds.first.date ).to be_a Date
    end


    it "manage  exchanges in a linklist " do
      ORD.open_class :Exchange
      predefined_property

      f = ActiveOrient::Model::Exchange.create :label => 'Frankfurt'
      b = ActiveOrient::Model::Exchange.create :label => 'Berlin'
      s = ActiveOrient::Model::Exchange.create :label => 'Stuttgart'
      ds = ActiveOrient::Model::Property.create con_id: 12355
      ds.add_item_to_property( :exchanges ){ [f,b,s] }
      #	  ds.add_item_to_property :exchanges, b
      #	  ds.add_item_to_property :exchanges, s
      expect( ds.exchanges ).to have(3).items
      expect( ActiveOrient::Model::Property.where( "'Stuttgart' in exchanges.label").first ).to eq ds
      expect( ActiveOrient::Model::Property.where( "'Hamburg' in exchanges.label") ).to  be_empty
      ds.remove_item_from_property( :exchanges){ [b,s] }
      expect( ds.exchanges ).to have(1).items
    end

    it "add  an embedded linkmap- entry " , :pending => true do
      pending( "Query Database for last entry does not work in 2.2" )
      predefined_property
      ORD.open_class :industry
      property_record=  ActiveOrient::Model::Property.create  con_id: 12346
      ['Construction','HealthCare','Bevarage'].each do | industry |
	property_record.add_item_to_property :property, ActiveOrient::Model::Industry.create( label: industry)
      end
      # to query: select * from Property where 'Stuttgart' in exchanges.label
      # or select * from Property where exchanges contains ( label = 'Stuttgart' )
      #
      pr =  ActiveOrient::Model::Property.where( "'HealthCare' in property.label").first
      expect( pr ).to eq property_record

      expect( property_record.con_id ).to eq 12346
      expect( property_record.property ).to be_a Array
      expect( property_record.property ).to have(3).records
      puts property_record.property.map( &:label).join(":")
      puts ActiveOrient::Model::Industry.all.map(&:label).join(" -- ")
      expect( property_record.property.last ).to eq ActiveOrient::Model::Industry.last

      expect( property_record.property[2].label ).to eq 'Bevarage'
      expect( property_record.property.find{|x| x.label == 'HealthCare'}).to be_a ActiveOrient::Model::Industry


    end

    ## rp['properties'] --> Array of
    #  {"name" => "exchanges", "linkedClass" => "Exchange",
    #   "type" => "LINKMAP", "mandatory" => false, "readonly" => false,
    #   "notNull" => false, "min" => nil, "max" => nil, "regexp" => nil,
    #   "collate" => "default"}
    #
    # disabled for now
    #     it "a new record is initialized with preallocated properties" do
    #	new_record =  Property.create
    #	ORD.get_class_properties(  Property )['properties'].each do | property |
    #	  expect( new_record.attributes.keys ).to include property['name']
    #
    #	end

    #      end


end

=begin ---> deprecated
        context "Use the Query-Class", focus: false do
          before(:all) do
            classname = "Documebntklasse10"
            #      ORD.delete_class @classname
            ORDest_class = ORD.create_class classname
            ORD.create_properties(  ORDest_class,
            { symbol: { propertyType: 'STRING' },
            con_id: { propertyType: 'INTEGER' }   } )

            @query_class =  ActiveOrient::Query.new
            #      @query_class.orientdb =  ORD
          end
          after(:all){  ORD.delete_class ORDest_class }

          it "the query class has the expected properties" do
            expect(@query_class.records ).to be_a Array
            expect(@query_class.records).to be_empty
          end

          it "get a document through the query-class" , focus: true do
            r=  ORD.create_document  ORDest_class, attributes: { con_id: 343, symbol: 'EWTZ' }
            expect( @query_class.get_documents ORDest_class, where: { con_id: 343, symbol: 'EWTZ' }).to eq 1
            expect( @query_class.records ).not_to be_empty
            expect( @query_class.records.first ).to eq r
            expect( @query_class.queries ).to have(1).record
            expect( @query_class.queries.first ).to eq "select from Documebntklasse10 where con_id = 343 and symbol = 'EWTZ'"

          end

          #    it "execute a query from stack" , do
          #     # get_documents saved the query
          #      # we execute this once more
          #       @query_class.reset_results
          #       expect( @query_class.records ).to be_empty
          #
          #       expect{ @query_class.execute_queries }.to change { @query_class.records.size }.to 1
          #
          #    end

        end

        context "execute batches"  do
          it "a simple batch" do
            ORD.delete_class 'Person'
            ORD.delete_class 'Car'
            ORD.delete_class 'Owns'
            res = ORD.execute  transaction: false do
              ## perform operations from the tutorial
              sql_cmd = -> (command) { { type: "cmd", language: "sql", command: command } }

              [ sql_cmd[ "create class Person extends V" ] ,
              sql_cmd[ "create class Car extends V" ],
              sql_cmd[ "create class Owns extends E"],

              sql_cmd[ "create property Owns.out LINK Person "],
              sql_cmd[ "create property Owns.in LINK Car "],
              sql_cmd[ "alter property Owns.out MANDATORY=true "],
              sql_cmd[ "alter property Owns.in MANDATORY=true "],
              sql_cmd[ "create index UniqueOwns on Owns(out,in) unique"],

              { type: 'c', record: { '@class' => 'Person' , name: 'Lucas' } },
              sql_cmd[ "create vertex Person set name = 'Luca'" ],
              sql_cmd[ "create vertex Car set name = 'Ferrari Modena'"],
              { type: 'c', record: { '@class' => 'Car' , name: 'Lancia Musa' } },
              sql_cmd[ "create edge Owns from (select from Person where name='Luca') to (select from Car where name = 'Lancia Musa')" ],
              sql_cmd[ "create edge Owns from (select from Person where name='Lucas') to (select from Car where name = 'Ferrari Modena')" ],
              sql_cmd[ "select name from ( select expand( out('Owns') ) from Person where name = 'Luca' )" ]
            ]
          end
          # the expected result: 1 dataset, name should be Ferrari
          expect( res).to be_a Array
          expect( res.size ).to eq 1
          expect( res.first.name).to eq  'Lancia Musa'
          expect( res.first).to be_a ActiveOrient::Model::Myquery

        end

      end
      # this must be the last test in file because the database itself is destroyed
      context "create and destroy a database" do


        it "list all databases" do
          # the temp-database is always present
          databases =  ORD.get_databases
          expect( databases ).to be_a Array
          expect( databases ).to include 'temp'

        end

        it "create a database" do
          newDB = 'newTestDatabase'
          r =  ORD.create_database database: newDB
          expect(r).to eq newDB
        end

        it "delete a database"  do

          rmDB = 'newTestDatabase'
          r = ORD.delete_database database: rmDB
          expect( r ).to be_truthy
        end
      end

=end

    end

    # response ist zwar ein String, verfügt aber über folgende Methoden
    # :to_json
    # :to_json_with_active_support_encoder,
    # :to_json_without_active_support_encoder,
    # :as_json,
    # :to_crlf
    # :to_lf
    # :to_nfc,
    # :to_nfd,
    # :to_nfkc,
    # :to_nfkd,
    # :to_json_raw,
    # :to_json_raw_object,
    # :valid_encoding?,
    # :request,
    # :net_http_res,
    # :args,
    # :headers,
    # :raw_headers,
    # :cookies,
    # :cookie_jar,
    # :description,
    # :follow_redirection,
    # :follow_get_redirection,
    #
