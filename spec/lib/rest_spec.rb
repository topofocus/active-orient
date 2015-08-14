
require 'spec_helper'
require 'active_support'


shared_examples_for 'a valid Class' do

end
describe ActiveOrient::OrientDB do
  
#  let(:rest_class) { (Class.new { include HCTW::Rest } ).new }

  before( :all ) do

    # working-database: hc_database
    ActiveOrient::Model.logger = Logger.new('/dev/stdout')
    @database_name = 'RestTest'
    r = ActiveOrient::OrientDB.new connect: false
    r.delete_database database: @database_name
    @r= ActiveOrient::OrientDB.new database: @database_name

    end


  context "check private methods", :private do
    it 'simple_uris' do
      expect( @r.property_uri('test')).to eq "property/#{@database_name}/test"
      expect( @r.command_sql_uri ).to eq "command/#{@database_name}/sql/"
      expect( @r.query_sql_uri ).to eq "query/#{@database_name}/sql/"
      expect( @r.database_uri ).to eq "database/#{@database_name}"
      expect( @r.document_uri ).to eq "document/#{@database_name}"
      expect( @r.class_uri ).to eq "class/#{@database_name}"
      expect( @r.class_uri {'test'} ).to eq "class/#{@database_name}/test"

    end
  end
  context "establish a basic-auth ressource"   do
    it "connect " do
      expect( @r.ressource ).to be_a RestClient::Resource
      expect( @r.connect ).to be_truthy
    end
  end


  context "perform database requests" do
      let( :classname ) { "new_class" }
      let( :edgename ) { "new_edge" }
      let( :vertexname ) { "new_vertex" }
      it 'class_name qualifies the classname-parameter'    do
	expect( @r.class_name classname ).to be_nil
	@r.open_class classname
	expect( @r.class_name classname ).to eq classname.camelize
	@r.delete_class classname
	expect( @r.class_name classname ).to be_nil

      end

      it "class_name can be invoked with a Klass-Const" do
	klass=  @r.open_class classname
	expect( klass ).to eq ActiveOrient::Model::NewClass
	expect( @r.class_name klass ).to eq classname.camelize
      end

    it "get all Classes" do
      classes = @r.get_classes 'name', 'superClass'

      # the standard-properties should always be present
      ["OFunction" , 
       "OIdentity" , "ORIDs" , "ORestricted" ,
       "ORole" , "OSchedule" , "OTriggered" , "OUser" ].each do |c|
	expect( classes.detect{ |x|  x['name'] == c } ).to be_truthy

      end
    end

    it "create  and delete a Class  "  do
      re = @r.delete_class  classname
#      expect( re ).to be_falsy
      model = @r.create_class  classname
      expect( model.new  ).to be_a ActiveOrient::Model
      expect( model.to_s ).to eq "ActiveOrient::Model::#{classname.camelize}"
      expect( @r.class_name  model ).to eq classname.camelize
      expect( @r.database_classes ).to include @r.class_name( classname )  
      expect( @r.delete_class( model ) ).to be_truthy
      expect( @r.database_classes ).not_to include @r.class_name( classname )
    end

    it "create and delete an Edge "  do
      # Edges are always Singular
      @r.delete_class  edgename
      model = @r.create_edge_class  edgename
      expect( model.new ).to be_a ActiveOrient::Model
      expect( model.superClass ).to eq "E"
      expect( model.to_s ).to eq "ActiveOrient::Model::#{edgename.camelize}"
      ## a freshly initiated edge does not have "in" and "out" properties and thus does not look like an edge
      expect( model.new.is_edge? ).to be_falsy
      expect( @r.class_name  model ).to eq edgename.camelize
      expect( @r.delete_class( model ) ).to be_truthy
      expect( @r.database_classes ).not_to include @r.class_name( classname )
    end

    it "create and delete a Vertex-Class"   do

      @r.delete_class vertexname
      expect( @r.database_classes ).not_to include @r.class_name( vertexname)
      myvertex = @r.create_vertex_class  vertexname
      expect(@r.database_classes ).to include @r.class_name( vertexname )
      expect( myvertex ).to be_a  Class
      expect( myvertex.new).to be_a ActiveOrient::Model
      expect( @r.class_hierachie( base_class: 'V').flatten ).to include @r.class_name( vertexname)
      expect( @r.delete_class vertexname ).to be_truthy
    end

    describe "create a bunch of classes"   do
      before(:all){ ["one", "two" , "trhee", :one_v, :two_v,  :trhee_v ].each{|x| @r.delete_class x.to_s  }}
      after(:all){ ["one", "two" , "trhee", :one_v, :two_v,  :trhee_v ].each{|x| @r.delete_class x.to_s  }}
      let( :classes_simple ) { ["one", "two" , "trhee"] }
      let( :classes_vertex ) { { v: [ :one_v, :two_v,  :trhee_v] } }


      it "init: database does not contain classes" do

	classes_simple.each{|x| expect( @r.database_classes ).not_to include @r.class_name(x) }
      end

      it "create  simple classes" do
	klasses = @r.create_classes classes_simple 
	classes_simple.each{|y| expect( @r.database_classes ).to include @r.class_name(y) }
	klasses.each{|x| expect(x.superclass).to eq ActiveOrient::Model }
      end
      it "create Vertex clases"  do
	klasses = @r.create_classes classes_vertex
	classes_vertex[:v].each{|y| expect( @r.database_classes ).to include @r.class_name(y) }
	klasses.each do |x|
	  expect(x.superclass).to eq ActiveOrient::Model 
	  expect(x.superClass).to eq 'V' 
	end
      end
    end

    describe "handle Properties at Class-Level"   do
      before(:all){ @r.create_class 'property' }
      after(:all){ @r.delete_class 'property' }


      it "Class is present" do
	expect( ActiveOrient::Model::Property.new_document ).to be_a ActiveOrient::Model
      end

      it "define some Properties"  do
	Property = @r.open_class 'property'
	@r.open_class 'contracts'
	rp = @r.create_properties( Property ) do
	  { symbol: { propertyType: 'STRING' },
	    con_id: { propertyType: 'INTEGER' } ,  
	    details: { propertyType: 'LINK', linkedClass: 'Contracts' }
	  }
	end

	expect( rp ).to eq 3

	rp= @r.get_class_properties  Property 

	# has "name"=>"Properties", "superClass"=>"", "superClasses"=>[], "alias"=>nil, "abstract"=>false, "strictmode"=>false, "clusters"=>[12], "defaultCluster"=>12, "clusterSelection"=>"round-robin", "records"=>0, "properties"=>[{"name"=>"con_id", "type"=>"INTEGER", "mandatory"=>false, "readonly"=>false, "notNull"=>false, "min"=>nil, "max"=>nil, "regexp"=>nil, "collate"=>"default"

	properties= rp['properties']
	[ :con_id, :symbol, :details].each do |f|
	  expect( properties.detect{|x| x['name']== f.to_s}  ).to be_truthy
	end
      end


    end
  end

  context "query-details" do
    it "generates a valid where nery-string" do
      attributes = { uwe: 34 }
      expect( @r.compose_where( attributes ) ).to eq "where uwe = 34" 
      attributes = { uwe: 34 , hans: :trz }
      expect( @r.compose_where( attributes ) ).to eq "where uwe = 34 and hans = 'trz'" 
      attributes = { uwe: 34 , hans: 'trzit'}
      expect( @r.compose_where( attributes ) ).to eq "where uwe = 34 and hans = 'trzit'" 
    end
  end
  context "document-handling"   do
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
      expect( res).to be_a ActiveOrient::Model
      expect( res.con_id ).to eq 345
      expect( res.symbol ).to eq 'EWQZ'
      expect( res.version).to eq 1
    end


    it "create through create_or_update"  do
      res=  @r.create_or_update_document   @rest_class , set: { a_new_property: 34 } , where: {con_id: 345, symbol: 'EWQZ' }
      expect( res ).to be_a @rest_class
      expect(res.a_new_property).to eq 34
      res2= @r.create_or_update_document(  @rest_class , set: { a_new_property: 35 } , where: {con_id: 345 } ) 
      expect( res2.a_new_property).to eq 35
      expect( res2.version).to eq res.version+1
    end

    it   "uses create_or_update and a block on an exiting document" do  ##update funktioniert nicht!!
      res=  @r.create_or_update_document   @rest_class , set: { a_new_property: 36 } , where: {con_id: 345, symbol: 'EWQZ' } do 
	{ another_wired_property: "No time for tango" }
      end

      expect( res.a_new_property).to eq 36
      expect( res.attributes.keys ).not_to include 'another_wired_property'  ## block is not executed, because its not a new document

    end
    it   "uses create_or_update and a block on a new document" do  
      res=  @r.create_or_update_document   @rest_class , set: { a_new_property: 36 } , where: {con_id: 345, symbol: 'EWQrGZ' } do 
	{ another_wired_property: "No time for tango" }
      end

      expect( res.a_new_property).to eq 36
      expect( res.attributes.keys ).to include 'another_wired_property'  ## block is executed, because its a new document

    end

    it "update strange text" do  # from the orientdb group
      strange_text = { strange_text: "'@type':'d','a':'some \\ text'"}

      res=  @r.create_or_update_document   @rest_class , set: { a_new_property: 36 } , where: {con_id: 346, symbol: 'EWQrGZ' } do 
	  strange_text
      end
      expect( res.strange_text ).to eq strange_text[:strange_text]
      document_from_db =  @r.get_document res.rid
      expect( document_from_db.strange_text ).to eq strange_text[:strange_text]
    end
    it "read that document" do
     r=  @r.create_document  @rest_class, attributes: { con_id: 343, symbol: 'EWTZ' }
     expect( r.class ).to eq @rest_class
     res = @r.get_documents  from: @rest_class, where: { con_id: 343, symbol: 'EWTZ' }
     expect(res.first.symbol).to eq r.symbol
     expect(res.first.version).to eq  r.version

    end

    it "count datasets in class" do
      r =  @r.count_documents  from: @rest_class
      expect( r ).to eq  4
    end

     it "updates that document"   do
       r=  @r.create_document  @rest_class, attributes: { con_id: 340, symbol: 'EWZ' }
       rr =  @r.update_documents  @rest_class,
	 set: { :symbol => 'TWR' },
	 where: { con_id: 340 }
	
       res = @r.get_documents   from: @rest_class, where:{ con_id: 340 }
       puts res.inspect
       expect( res.size ).to eq 1
       expect( res.first['symbol']).to eq 'TWR'

     end
     it "deletes that document" do
     @r.create_document  @rest_class , attributes: { con_id: 3410, symbol: 'EAZ' }
     r=  @r.delete_documents  @rest_class , where: { con_id: 3410 }

     res = @r.get_documents  from: @rest_class, where: { con_id: 3410 }
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
      @query_class =  ActiveOrient::Query.new
#      @query_class.orientdb =  @r
    end
    after(:all){  @r.delete_class @rest_class }

    it "the query class has the expected properties" do
      expect(@query_class.records ).to be_a Array
      expect(@query_class.records).to be_empty
    end

    it "get a document through the query-class" , pending: true do
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
      expect( res.first).to be_a ActiveOrient::Model::Myquery

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
      r =  @r.create_database database: newDB
      expect(r).to eq newDB
    end

    it "delete a database"  do

      rmDB = 'newTestDatabase'
      r = @r.delete_database database: rmDB
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
