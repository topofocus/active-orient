
require 'spec_helper'
require 'active_support'
require 'connect_helper'


shared_examples_for 'a valid Class' do

end
describe ActiveOrient::OrientDB do

  #  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }

  before( :all ) do

   ORD  =  connect( database: 'RestTest' )
    # working-database: hc_database
    @database_name = 'RestTest'

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
        ORD.open_class :contract
        ph= { :type => :link, linked_class: :contract }
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
        ph= {:propertyType=>"STRING", linked_class: :contract }
        field = 't'
        expect( ORD.translate_property_hash field , ph ).to eq  field => {:propertyType=>"STRING", :linkedClass=>"Contract"}
        ph= {:propertyType=> :string, linkedClass: :contract }
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


  context "perform database requests" do
    let( :class_name ) { "new_class" }
    let( :edge_name ) { "new_edge" }
    let( :vertex_name ) { "new_vertex" }

    it 'class_name qualifies the classname-parameter'   do
      expect( ORD.classname class_name ).to be_nil
      ORD.open_class class_name
      expect( ORD.classname class_name ).to eq class_name.capitalize_first_letter
      ORD.delete_class class_name
      expect( ORD.classname class_name ).to be_nil

    end

    it "class_name can be invoked with a Klass-Const" do
      klass=  ORD.open_class class_name
      expect( klass ).to eq ActiveOrient::Model::New_class
      expect( ORD.classname klass ).to eq class_name.capitalize_first_letter

    end

    it "get all Classes" do
      classes = ORD.get_classes 'name', 'superClass'

      # the standard-properties should always be present
      ["OFunction" ,
        "OIdentity" , "ORIDs" , "ORestricted" ,
        "ORole" , "OSchedule" , "OTriggered" , "OUser" ].each do |c|
          expect( classes.detect{ |x|  x['name'] == c } ).to be_truthy
        end
      end

      it "create  and delete a Class  "  do
        re = ORD.delete_class  class_name
        #      expect( re ).to be_falsy
        model = ORD.create_class  class_name
        expect( model.new  ).to be_a ActiveOrient::Model
	expect( model.to_s ).to eq "ActiveOrient::Model::#{class_name.capitalize_first_letter}"
        expect( ORD.classname  model ).to eq class_name.capitalize_first_letter
        expect( ORD.database_classes ).to include ORD.classname( class_name )
        expect( ORD.delete_class( model ) ).to be_truthy
        expect( ORD.database_classes ).not_to include ORD.classname( class_name )
      end

      it "create and delete an Edge "  do
        # Edges are always Singular
        ORD.delete_class  edge_name
        model = ORD.create_edge_class  edge_name
        expect( model.new ).to be_a ActiveOrient::Model
        expect( model.superClass ).to eq "E"
        expect( model.to_s ).to eq "ActiveOrient::Model::#{edge_name.capitalize_first_letter}"
        ## a freshly initiated edge does not have "in" and "out" properties and thus does not look like an edge
        expect( model.new.is_edge? ).to be_falsy
        expect( ORD.classname  model ).to eq edge_name.capitalize_first_letter
        expect( ORD.delete_class( model ) ).to be_truthy
        expect( ORD.database_classes ).not_to include ORD.classname( class_name )
      end

      it "create and delete a Vertex-Class"   do

        ORD.delete_class vertex_name
        expect( ORD.database_classes ).not_to include ORD.classname( vertex_name)
        myvertex = ORD.create_vertex_class  vertex_name
        expect(ORD.database_classes ).to include ORD.classname( vertex_name )
        expect( myvertex ).to be_a  Class
        expect( myvertex.new).to be_a ActiveOrient::Model
        expect( ORD.class_hierarchy( base_class: 'V', requery: true).flatten ).to include ORD.classname( vertex_name)
        expect( ORD.delete_class vertex_name ).to be_truthy
      end
    end
    describe "create a bunch of classes"      do
      before(:all){ ["one", "two" , "trhee", :one_v, :two_v,  :trhee_v ].each{|x| ORD.delete_class x.to_s  }}
      after(:all){ ["one", "two" , "trhee", :one_v, :two_v,  :trhee_v ].each{|x| ORD.delete_class x.to_s  }}
      let( :classes_simple ) { ["one", "two" , "trhee"] }
      let( :classes_vertex ) { { v: [ :one_v, :two_v,  :trhee_v] } }


      it "init: database does not contain classes" do

        classes_simple.each{|x| expect( ORD.database_classes ).not_to include ORD.classname(x) }
      end

      it "create  simple classes" do
        klasses = ORD.create_classes classes_simple
        classes_simple.each{|y| expect( ORD.database_classes ).to include ORD.classname(y) }
        klasses.each{|x| expect(x.superclass).to eq ActiveOrient::Model }
      end
      it "create Vertex clases"  do
        klasses = ORD.create_classes classes_vertex
        classes_vertex[:v].each{|y| expect( ORD.database_classes ).to include ORD.classname(y) }
        klasses.each do |x|
          expect(x.superclass).to eq ActiveOrient::Model
          expect(x.superClass).to eq 'V'
        end
      end

      describe "handle Properties at Class-Level"  do
        before(:each){ ORD.delete_class 'property'; 	Property = ORD.open_class 'property' }
        # after(:all){ ORD.delete_class 'property' }
	let( :predefined_property ) do
          rp = ORD.create_properties( ActiveOrient::Model::Property,
          symbol: { propertyType: 'STRING' },
          con_id: { propertyType: 'INTEGER' } ,
          exchanges: { propertyType: 'LINKLIST', linkedClass: 'Exchange' } ,
          details: { propertyType: 'LINK', linkedClass: 'Contract' },
          date: { propertyType: 'DATE' }
          )
	end

        it "define Properties in several ways"  do
	  [ :t1, :t2, :t3  ].each do | cl |
	    ORD.delete_class cl
	    ORD.open_class cl
	  end
          ORD.open_class :Exchange_Class

          r1 = ORD.create_properties :t1, symbol: { propertyType: 'LINKLIST', linkedClass: 'Exchange_Class' }
          r2 = ORD.create_properties :t2, symbol: { propertyType: 'LINKLIST', linkedClass: :exchange_Class }
          r3 = ORD.create_properties :t3, symbol: { propertyType: 'LINKLIST', linkedClass: :Exchange_Class }

          expect( r1 ). to eq r2
          expect( r1 ). to eq r3
          expect( r3 ). to eq r2
        end
        it "define some Properties on class Property" do
          ORD.open_class :contract
         # ORD.open_class :Exchange
         # rp = ORD.create_properties( Property ,
         # symbol: { propertyType: 'STRING' },
         # con_id: { propertyType: 'INTEGER' } ,
         # exchanges: { propertyType: 'LINKLIST', linkedClass: 'Exchange' } ,
         # details: { propertyType: 'LINK', linkedClass: 'Contract' },
         # date: { propertyType: 'DATE' }
         # )


          expect( predefined_property ).to eq 5
          rp= ORD.get_class_properties(  Property )['properties']

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
	    {	"name"=>"Contract_detail.con_id",
       "type"=>"UNIQUE",
       "fields"=>["con_id"] } )


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
	  linked_record = ActiveOrient::Model::Industry.create label: 'TestIndustry'
	  expect{ Property.update_or_create where: { con_id: 12345 }, 
		    set: { industry: linked_record.rid, 
		    date: Date.parse( "2011-04-04") } 
		}.to change{ Property.count }.by 1

	  ds = Property.where con_id: 12345
	  expect( ds ).to be_a Array
	  expect( ds.first ).to be_a Property
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
	  ds = Property.create con_id: 12355
	  ds.add_item_to_property( :exchanges ){ [f,b,s] }
#	  ds.add_item_to_property :exchanges, b
#	  ds.add_item_to_property :exchanges, s
	  expect( ds.exchanges ).to have(3).items
	  expect( Property.where( "'Stuttgart' in exchanges.label").first ).to eq ds
	  expect( Property.where( "'Hamburg' in exchanges.label") ).to  be_empty
	  ds.remove_item_from_property( :exchanges){ [b,s] }
	  expect( ds.exchanges ).to have(1).items
	end

	it "add  an embedded linkmap- entry " do
	  predefined_property
	  ORD.open_class :industry
	  property_record=  Property.create  con_id: 12346
	  ['Construction','HealthCare','Bevarage'].each do | industry |
	    property_record.add_item_to_property :property, ActiveOrient::Model::Industry.create( label: industry)
	  end
              # to query: select * from Property where 'Stuttgart' in exchanges.label
              # or select * from Property where exchanges contains ( label = 'Stuttgart' )
              #
              pr =  Property.where( "'HealthCare' in property.label").first
              expect( pr ).to eq property_record

              expect( property_record.con_id ).to eq 12346
              expect( property_record.property ).to be_a Array
              expect( property_record.property ).to have(3).records
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
        end

        context "create and manage a 2 layer 1:n relation"  do
          before(:all) do
	    [ :base, :first_list, :second_list ].each do| cl |
	      ORD.delete_class cl
	      ORD.create_vertex_class cl
	    end
            ORD.create_properties :base,  first_list: { type: :linklist, linkedClass: :first_list }
            ORD.create_properties :first_list,  second_list: { type: :linklist, linkedClass: :second_list }
            ORD.create_vertex_class :log
            (0 .. 9).each do | b |
              base= ActiveOrient::Model::Base.create label: b

              (0 .. 9).each do | f |
                first = ActiveOrient::Model::First_list.create label: f
                base.add_item_to_property :first_list , first

                (0 .. 9).each do | s |
                  second=  ActiveOrient::Model::Second_list.create label: s
                  first.add_item_to_property :second_list, second
                end
              end
            end
          end

          it "check base"  do
            (0..9).each do | b |
              base =  ActiveOrient::Model::Base.where( label: b)
	      expect( base).to be_a Array
	      expect( base.size ).to eq 1
	      base= base.first
              expect( base.first_list ).to be_a Array
              expect( base.first_list ).to have(10).items
              base.first_list.each{|fl| expect( fl.second_list ).to have(10).items }
            end
          end

          it "query local structure" do
            ActiveOrient::Model::Base.all.each do | base |
              (0 .. 9).each do | c |
                (0 .. 9).each do | d |
                  expect( base.first_list[c].second_list[d].label ).to eq d
                end
              end
            end

            q =  OrientSupport::OrientQuery.new  from: :base
            q.projection << 'expand( first_list[5].second_list[9] )'
            q.where << { label: 9 }
            expect( q.to_s ).to eq 'select expand( first_list[5].second_list[9] ) from base where label = 9 '
            result1=  ORD.get_documents( query: q).first
            result2 = ActiveOrient::Model::Base.query_database( q ).first
            expect( result2).to be_a ActiveOrient::Model::Second_list
            expect( result1 ).to eq result2
            #     expect( result.first ).to eq ActiveOrient::Model::Base[9].first_list[5].second_list[9]

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
            ORD.create_properties( ORDest_class,
            { symbol: { propertyType: 'STRING' },
            con_id: { propertyType: 'INTEGER' } ,
            details: { propertyType: 'LINK', linkedClass: 'Contract' } } )


          end
          after(:all){  ORD.delete_class ORDest_class }


          it "create a single document"  do
            res=  ORD.create_document ORDest_class , attributes: {con_id: 345, symbol: 'EWQZ' }
            expect( res ).to be_a ActiveOrient::Model
            expect( res.con_id ).to eq 345
            expect( res.symbol ).to eq 'EWQZ'
            expect( res.version).to eq 1
          end


          it "create through create_or_update"  do
            res=  ORD.create_or_update_document   ORDest_class , set: { a_new_property: 34 } , where: {con_id: 345, symbol: 'EWQZ' }
            expect( res ).to be_a ORDest_class
	    puts res.attributes
            expect(res.a_new_property).to eq 34
            res2= ORD.create_or_update_document  ORDest_class , set: { a_new_property: 35 } , where: {con_id: 345 }
	    puts "res2"
	    puts res2.inspect
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
              ORDes=  ORD.create_or_update_document( ORDest_class ,
              set: { a_new_property: 37 } ,
              where: {con_id: 345, symbol: 'EWQrGZ' }) do
                { another_wired_property: "No time for tango" }
              end
            end.to change{ ORDest_class.count }.by 1

            expect( ORDes.a_new_property).to eq 37
            expect( ORDes.attributes.keys ).to include 'another_wired_property'  ## block is executed, because its a new document

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



          end
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
