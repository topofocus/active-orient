
require 'spec_helper'
require 'active_support'


shared_examples_for 'a valid Class' do

end
describe REST::OrientDB do
  
#  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }

  before( :all ) do

    # working-database: hc_database
#    REST::Model.logger = Logger.new('/dev/stdout')
    @r= REST::OrientDB.new database: 'hc_database' , :connect => false
    REST::Model.orientdb = @r
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
      let( :classname ) { "Neueklasse10" }

    it "get all Classes" do
      classes = @r.get_classes 'name', 'superClass'

      # the standard-properties should always be present
      ["E","V", "OFunction" , 
       "OIdentity" , "ORIDs" , "ORestricted" ,
       "ORole" , "OSchedule" , "OTriggered" , "OUser" ].each do |c|
	expect( classes.detect{ |x|  x['name'] ==c } ).to be_truthy

      end
    end

    it "create  and delete a Class  " do
      re = @r.delete_class  classname
#      expect( re ).to be_falsy
      model = @r.create_class  classname
      expect(model.new).to be_a REST::Model
      rr = @r.create_class  classname
      expect(model.to_s).to eq 'REST::Model::Neueklasse10'
      re = @r.delete_class model
      expect( re ).to be_truthy
      expect(  @r.get_classes( 'name' ) ).not_to include( { 'name' => classname } )
      rr = @r.create_class  classname
      # the class is created again
      expect(  @r.get_classes( 'name' ) ).to include( { 'name' => classname } )
    end


    describe "create a bunch of classes"  do
      before(:all){ ["one", "two" , "trhee", :one_v, :two_v,  :trhee_v ].each{|x| @r.delete_class x.to_s  }}
      let( :classes_simple ) { ["one", "two" , "trhee"] }
      let( :classes_vertex ) { { v: [ :one_v, :two_v,  :trhee_v] } }

    
      it "init: database does not contain classes" do

	classes_simple.each{|x| expect( @r.database_classes ).not_to include x }
      end

      it "create  simple classes" do
	klasses = @r.create_classes classes_simple 
	classes_simple.each{|y| expect( @r.database_classes( requery: true) ).to include y }
	klasses.each{|x| expect(x.superclass).to eq REST::Model }
      end
      it "create Vertex clases" do
	klasses = @r.create_classes classes_vertex
	classes_vertex[:v].each{|y| expect( @r.database_classes( requery: true) ).to include y.to_s }
	klasses.each{|x| expect(x.superclass).to eq REST::Model }

      end
    end

    it "create and delete an Edge-Class"  do
    
    classname = 'Myedge'
    @r.delete_class classname
    expect( @r.database_classes( requery:true )).not_to include classname
    myedge = @r.create_edge_class  classname
    expect(@r.database_classes( :requery => true )).to include classname
    expect( myedge ).to be_a  Class
    expect( myedge.new).to be_a REST::Model
    expect( @r.class_hierachie( base_class: 'E') ).to include classname
  end
    it "create and delete an Vertex-Class"   do
    
    classname = 'Myvertex'
    @r.delete_class classname
    expect( @r.database_classes( requery:true )).not_to include classname
    myvertex = @r.create_vertex_class  classname
    expect(@r.database_classes( :requery => true )).to include classname
    expect( myvertex ).to be_a  Class
    expect( myvertex.new).to be_a REST::Model
    expect( @r.class_hierachie( base_class: 'V') ).to include classname
  end

    it "creates a class and puts a property into "  do
      @r.delete_class classname
      @r.database_classes( requery:true )
      model = @r.create_class classname
      @r.create_class  "Contracts"

      rp = @r.create_properties( model ) do
	{ symbol: { propertyType: 'STRING' },
	  con_id: { propertyType: 'INTEGER' } ,  
	  details: { propertyType: 'LINK', linkedClass: 'Contracts' }
	}
	#quatsch: { propertyType: 'LINK', linkedClass: 'Multiquiatsch' }# --> error: Missing linked class
      end
      expect( rp ).to eq 3

      expect( @r.create_property model, field:'name', type: 'date').to eq 4
      expect( @r.delete_property model, field:'name').to be_truthy
    end
    it "reads Properties form a class" do

      rp= @r.get_class_properties  classname
      # has "name"=>"neue_klasse10", "superClass"=>"", "superClasses"=>[], "alias"=>nil, "abstract"=>false, "strictmode"=>false, "clusters"=>[12], "defaultCluster"=>12, "clusterSelection"=>"round-robin", "records"=>0, "properties"=>[{"name"=>"con_id", "type"=>"INTEGER", "mandatory"=>false, "readonly"=>false, "notNull"=>false, "min"=>nil, "max"=>nil, "regexp"=>nil, "collate"=>"default"
      properties= rp['properties']
      [ :con_id, :symbol, :details].each do |f|
	expect( properties.detect{|x| x['name']== f.to_s}  ).to be_truthy
      end


    end
  end

  context "query-details" do
    it "generates a valid where nery-string" do
      attributes = { uwe: 34 }
      expect( @r.compose_where( attributes ) ).to eq " where uwe = 34" 
      attributes = { uwe: 34 , hans: :trz }
      expect( @r.compose_where( attributes ) ).to eq " where uwe = 34 and hans = 'trz'" 
      attributes = { uwe: 34 , hans: 'trzit'}
      expect( @r.compose_where( attributes ) ).to eq " where uwe = 34 and hans = 'trzit'" 
    end
  end
  context "document-handling"  do
    before(:all) do
      classname = "Documebntklasse10" 
#      @r.delete_class @classname 
      @rest_class = @r.create_class classname 
      @r.create_properties( @rest_class ) do
	{ symbol: { propertyType: 'STRING' },
	  con_id: { propertyType: 'INTEGER' } ,  
	  details: { propertyType: 'LINK', linkedClass: 'Contracts' }
	}
      end
    end
    after(:all){  @r.delete_class @rest_class }


    it "create a single document"  do
      res=  @r.create_document @rest_class , attributes: {con_id: 345, symbol: 'EWQZ' }
      puts res.inspect
      expect( res).to be_a REST::Model
      expect( res.con_id ).to eq 345
      expect( res.symbol ).to eq 'EWQZ'
      expect( res.version).to eq 1
    end


    it "create through create_or_update"  do
      res=  @r.create_or_update_document  @rest_class , set: { a_new_property: 34 } , where: {con_id: 345, symbol: 'EWQZ' }
      expect( res ).to be_a @rest_class
      expect(res.a_new_property).to eq 34
      res2= @r.create_or_update_document( @rest_class , set: { a_new_property: 35 } , where: {con_id: 345 } ) 
      expect( res2.a_new_property).to eq 35
      expect( res2.version).to eq res.version+1
    end

    it   "uses create_or_update and a block on an exiting document" do  ##update funktioniert nicht!!
      res=  @r.create_or_update_document  @rest_class , set: { a_new_property: 36 } , where: {con_id: 345, symbol: 'EWQZ' } do 
	{ another_wired_property: "No time for tango" }
      end

      expect( res.a_new_property).to eq 36
      expect( res.attributes.keys ).not_to include 'another_wired_property'  ## block is not executed, because its not a new document

    end
    it   "uses create_or_update and a block on a new document"  do  
      res=  @r.create_or_update_document  @rest_class , set: { a_new_property: 36 } , where: {con_id: 345, symbol: 'EWQrGZ' } do 
	{ another_wired_property: "No time for tango" }
      end

      expect( res.a_new_property).to eq 36
      expect( res.attributes.keys ).to include 'another_wired_property'  ## block is executed, because its a new document

    end

    it "update strange text" do  # from the orientdb group
      strange_text = { strange_text: "'@type':'d','a':'some \\ text'"}

      res=  @r.create_or_update_document  @rest_class , set: { a_new_property: 36 } , where: {con_id: 346, symbol: 'EWQrGZ' } do 
	  strange_text
      end
      expect( res.strange_text ).to eq strange_text[:strange_text]
      document_from_db =  @r.get_document res.rid
      expect( document_from_db.strange_text ).to eq strange_text[:strange_text]
    end
    it "read that document" do
     r=  @r.create_document  @rest_class, attributes: { con_id: 343, symbol: 'EWTZ' }
     expect( r.class ).to eq @rest_class
     res = @r.get_documents  @rest_class, where: { con_id: 343, symbol: 'EWTZ' }
     expect(res.first.symbol).to eq r.symbol
     expect(res.first.version).to eq  r.version

    end

    it "count datasets in class" do
      r =  @r.count_documents  @rest_class
      expect( r ).to eq  4
    end

     it "updates that document" do
       r=  @r.create_document  @rest_class, attributes: { con_id: 340, symbol: 'EWZ' }
       rr =  @r.update_documents  @rest_class,
	 set: { :symbol => 'TWR' },
	 where: { con_id: 340 }
	
       res = @r.get_documents   @rest_class, where:{ con_id: 340 }
       puts res.inspect
       expect( res.size ).to eq 1
       expect( res.first['symbol']).to eq 'TWR'

     end
     it "deletes that document" do
     @r.create_document  @rest_class , attributes: { con_id: 3410, symbol: 'EAZ' }
     r=  @r.delete_documents  @rest_class , where: { con_id: 3410 }

     res = @r.get_documents  @rest_class, where: { con_id: 3410 }
     expect(r.size).to eq 1



    end
  end

  context "Use the Query-Class" do 
    before(:all) do
      classname = "Documebntklasse10" 
#      @r.delete_class @classname 
      @rest_class = @r.create_class classname 
      @r.create_properties(  @rest_class ) do
	{ symbol: { propertyType: 'STRING' },
	  con_id: { propertyType: 'INTEGER' }   
	}
      end
      @query_class =  REST::Query.new
#      @query_class.orientdb =  @r
    end
    after(:all){  @r.delete_class @rest_class }

    it "the query class has the expected properties" do
      expect(@query_class.records ).to be_a Array
      expect(@query_class.records).to be_empty
    end

    it "get a document through the query-class" do
     r=  @r.create_document  @rest_class, attributes: { con_id: 343, symbol: 'EWTZ' }
     expect( @query_class.get_documents @rest_class, where: { con_id: 343, symbol: 'EWTZ' }).to eq 1
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
      expect( res).to be_a Array
      expect( res.size ).to eq 1 
      expect( res.first.name).to eq  'Lancia Musa'
      expect( res.first).to be_a REST::Model::Myquery

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
