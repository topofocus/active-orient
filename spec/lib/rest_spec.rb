
require 'spec_helper'
require 'active_support'

describe REST::OrientDB do
  
#  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }

  before( :all ) do

    # working-database: hc_database
    @r= REST::OrientDB.new database: 'hc_database' , :connect => false
    databases =  @r.get_databases
    unless databases.include? 'hc_database'
      @r.create_database name: 'hc_database'
    end

    end


  context "check private methods", :private do
    it 'simple_uris' do
      expect( @r.property_uri('test')).to eq "property/hc_database/test"
      expect( @r.command_sql_uri ).to eq "command/hc_database/sql/"
      expect( @r.query_sql_uri ).to eq "query/hc_database/sql/"
      expect( @r.database_uri ).to eq "database/hc_database"
      expect( @r.document_uri ).to eq "document/hc_database"
      expect( @r.class_uri ).to eq "class/hc_database"
      expect( @r.class_uri {'test'} ).to eq "class/hc_database/test"

    end
  end
  context "establish a basic-auth ressource"   do
    it "connect " do
      expect( @r.ressource ).to be_a RestClient::Resource
      expect( @r.connect ).to be_truthy
    end
  end


  context "perform database requests" do
      let( :classname ) { "NeueKlasse10" }

    it "get all Classes" do
      classes = @r.get_classes 'name', 'superClass'

      # the standard-properties should always be present
      ["E","V", "OFunction" , 
       "OIdentity" , "ORIDs" , "ORestricted" ,
       "ORole" , "OSchedule" , "OTriggered" , "OUser" ].each do |c|
	expect( classes.detect{ |x|  x['name'] ==c } ).to be_truthy

      end
    end

    it "create  and delete a Class  "  do
      re = @r.delete_class  classname
#      expect( re ).to be_falsy
      rr = @r.create_class  classname
      expect(rr).to match /[0-9]{1,}/
      rr = @r.create_class  classname
      expect(rr).to be_nil
      re = @r.delete_class classname
      expect( re ).to be_truthy
    end

    it "creates a class and put a property into "  do
      re = @r.delete_class classname
      rr = @r.create_class classname
      @r.create_class  "Contracts#"

      rp = @r.create_properties( class_name: classname ) do
	{ symbol: { propertyType: 'STRING' },
	  con_id: { propertyType: 'INTEGER' } ,  
	  details: { propertyType: 'LINK', linkedClass: 'Contracts' }
	}
	#quatsch: { propertyType: 'LINK', linkedClass: 'Multiquiatsch' }# --> error: Missing linked class
      end
      expect( rp ).to eq 3

      expect( @r.create_property class_name: classname, field:'name', type: 'date').to eq 4
      expect( @r.delete_property class_name: classname, field:'name').to be_truthy
    end
    it "reads Properties form a class" do

      rp= @r.get_class_properties class_name: classname
      # has "name"=>"neue_klasse10", "superClass"=>"", "superClasses"=>[], "alias"=>nil, "abstract"=>false, "strictmode"=>false, "clusters"=>[12], "defaultCluster"=>12, "clusterSelection"=>"round-robin", "records"=>0, "properties"=>[{"name"=>"con_id", "type"=>"INTEGER", "mandatory"=>false, "readonly"=>false, "notNull"=>false, "min"=>nil, "max"=>nil, "regexp"=>nil, "collate"=>"default"
      properties= rp['properties']
      [ :con_id, :symbol, :details].each do |f|
	expect( properties.detect{|x| x['name']== f.to_s}  ).to be_truthy
      end


    end
  end
  context "document-handling" do
    before(:all) do
      @classname = "DocumebntKlasse10" 
      @r.delete_class @classname 
      @r.create_class @classname 
      @r.create_properties( class_name: @classname ) do
	{ symbol: { propertyType: 'STRING' },
	  con_id: { propertyType: 'INTEGER' } ,  
	  details: { propertyType: 'LINK', linkedClass: 'Contracts' }
	}
      end
    end
    after(:all){  @r.delete_class @classname }


    it "create a single document" do
      res=  @r.create_document class_name: @classname , attributes: {con_id: 345, symbol: 'EWQZ' }
      expect( res['@type'] ).to eq 'd'
      expect( res['@version'] ).to eq 1
      expect( res['@class'] ).to eq @classname
      expect( res['con_id'] ).to eq  345
      expect( res['symbol'] ).to eq 'EWQZ'

    end


    it "read that document" do
     r=  @r.create_document class_name: @classname, attributes: { con_id: 343, symbol: 'EWTZ' }
     res = @r.get_documents class_name: @classname, where: { con_id: 343, symbol: 'EWTZ' }
     expect(res.first ).to eq r

    end

     it "updates that document" do
       r=  @r.create_document class_name: @classname, attributes: { con_id: 340, symbol: 'EWZ' }
       rr =  @r.update_documents class_name: @classname,
	 set: { :symbol => 'TWR' },
	 where: { con_id: 340 }

       res = @r.get_documents class_name: @classname, where:{ con_id: 340 }
       expect( res.size ).to eq 1
       expect( res.first['symbol']).to eq 'TWR'

     end
     it "deletes that document" do
     @r.create_document class_name: @classname , attributes: { con_id: 3410, symbol: 'EAZ' }
     r=  @r.delete_documents class_name: @classname , where: { con_id: 3410 }

     res = @r.get_documents class_name: @classname, where: { con_id: 3410 }
     expect(r.size).to eq 1



    end
  end


  context "execute batches" do
    it "a simple batch" do
      @r.delete_class 'Person'
      @r.delete_class 'Car'
      @r.delete_class 'Owns'
      res = @r.execute  transaction: false do 
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
      expect( res.size ).to eq 1 
      expect( res.first['name']).to eq  'Lancia Musa'


    end
  end
  # this must be the last test in file because the database itself is destroyed
  context "create and destroy a database" do


    it "list all databases" do
      # the temp-database is always present
      databases =  @r.get_databases
      expect( databases ).to be_a Array
      expect( databases ).to include 'temp'

    end

    it "create a database" do
      newDB = 'newTestDatabase'
      r =  @r.create_database name: newDB
      expect(r).to eq newDB
    end

    it "delete a database" do

      rmDB = 'newTestDatabase'
      r = @r.delete_database name: rmDB
      expect( r ).to be_truthy
    end
  end



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
