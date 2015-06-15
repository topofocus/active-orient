module REST
require 'cgi'
require 'rest-client'
require 'active_support/core_ext/string'  # provides blank?, present?, presence etc
#require 'model'
=begin
OrientDB performs queries to a OrientDB-Database

The communication is based on the REST-API.

The OrientDB-Server is specified in connect.yml, 
 :orientdb:
   :server: delta   #localhost
     :port: 2480
   :database: hc_database   # working-database
   :admin:
     :user: admin-user 
     :pass: admin-password


=end
class OrientDB
  mattr_accessor :logger  ## borrowed from active_support

=begin
Contructor: OrientDB is conventionally initialized. 
Thus several instances pointing to the same or different databases can coexist 

A simple 
 xyz =  REST::OrientDB.new
uses the database specified in the yaml-file »config/connect.yml« 
and connects 

=end

  def initialize database: nil,  connect: true
    @res = get_ressource
    @database = database|| YAML::load_file( File.expand_path('../../config/connect.yml',__FILE__))[:orientdb][:database] 
    connect() if connect
    # save existing classes 
    @classes = []
  end

##  use for development , should be removed in production release  
  def ressource
    @res
  end
## 

  def connect 
    r= @res["/connect/#{ @database }" ].get
    r.code == 204 ? true : nil 
  end

## -----------------------------------------------------------------------------------------
## 
## Database stuff
## 
##  get_databases
##  create_database
##  change_database
##  delete_database
## -----------------------------------------------------------------------------------------

=begin
returns an Array with Database-Names as Elements
=end
    def get_databases
       JSON.parse( @res["/listDatabases"].get.body)['databases']
    end

=begin
Creates a database with the given name and switches to this database as working-database
Types are either 'plocal' or 'memory' 

returns the name of the working-database
=end
    def create_database type: 'plocal' , name: @database
          logger.progname = 'OrientDB#CreateDatabase'
	  old_d = @database
	  @classes = []
	  @database = name
	  begin
          response = @res[database_uri{ type }].post  ""
	  if response.code == 200
	    logger.info{ "Database #{@database} successfully created and stored as working database"}
	  else
	    @database = old_d
	    logger.error{ "Database #{name} was NOT created. Working Database is still #{@database} "}
	  end
	  rescue RestClient::InternalServerError => e
	    @database = old_d
	    logger.error{ "Database #{name} was NOT created. Working Database is still #{@database} "}
	  end
	  @database

    end
=begin
changes the working-database to {name}
=end
    def change_database name 
      @classes = []
      @database =  name

    end
=begin
deletes the database and returns true on success

after the removal of the database, the working-database might be empty
=end
    def delete_database name:
      @classes = []
      logger.progname = 'OrientDB#DropDatabase'
       old_ds =  @database
       change_database name
       begin
	 response = @res[database_uri].delete
	 if name == old_ds
	   change_database ""
	   logger.info{ "Working database deleted" }
	 else
	   change_database old_ds
	   logger.info{ "Database #{name} deleted, working database is still #{@database} "}
	 end
       rescue RestClient::InternalServerError => e
	 logger.info{ "Database #{name} NOT deleted" }
	 change_database old_ds
       end
      !response.nil?  && response.code == 204 ?  true : false

    end

## -----------------------------------------------------------------------------------------
##          
##  Inspect, Create and Delete Classes
##  
##  inspect_classes
##  create_class
##  delete_class
##
## -----------------------------------------------------------------------------------------
    
=begin
returns an Array with Class-attribute-hash-Elements
eg
get_classes 'name', 'superClass'
returns
[ {"name"=>"E", "superClass"=>""}, 
  {"name"=>"OFunction", "superClass"=>""}, 
  {"name"=>"ORole", "superClass"=>"OIdentity"}
  (...)
]
=end

    def get_classes *attributes
      response =   @res[database_uri].get
      if response.code == 200
       classes=  JSON.parse( response.body )['classes' ]
       unless attributes.empty?
        classes.map{|y| y.select{| v,_| attributes.include?(v) } }
       else
	 classes
       end

       #.map{ |y| y.name }
      else
	[]
      end

    end

=begin
returns an array with all names of the classes of the database
caches the result.

parameter: include_system_classes: false|true, requery: false|true
=end
    def database_classes include_system_classes: false, requery: false
      requery =  true if @classes.empty?
      if requery
      system_classes = ["OFunction", "OIdentity", "ORIDs", "ORestricted", "ORole", "OSchedule", "OTriggered", "OUser", "V", "_studio","E"]
      all_classes = get_classes( 'name' ).map( &:values).flatten
      @classes = include_system_classes ? all_classes : all_classes - system_classes 
      end
      @classes 
    end

    alias inspect_classes database_classes 
    
=begin
creates a class and returns the a REST::Model:{Newclass}-Class- (Constant)
which is designed to take any documents stored in this class

Predefined attributes: version, cluster, record
Other attributes are assigned dynamically upon reading documents
=end
    def create_class   newclass
      logger.progname= 'OrientDB#CreateClass'
      if database_classes.include? newclass
	# reuse predefined class
	REST::Model.orientdb_class( name: newclass)
      else
	begin
	  response = @res[ class_uri{ newclass } ].post ''
	  ror_class= REST::Model.orientdb_class( name: newclass)
	  yield ror_class if block_given?   #  perform actions only if the class was sucessfully created
	  ror_class # return_value
	rescue RestClient::InternalServerError => e
	  # expected answer: {"errors"=>[{"code"=>500, "reason"=>500, "content"=>"java.lang.IllegalArgumentException: Class 'NeueKlasse10' already exists"}]}
	  if e.http_body.split(':').last =~ /already exists/
	    REST::Model.orientdb_class( name: newclass)
	  else
	    logger.error { "Class #{newclass} was NOT created" }
	    nil
	  end
	end # exeception
      end 
    end

    def create_edge_class name: , superclass: 'E'
      unless database_classes( requery: true).include? name
       sql_cmd = -> (command) { { type: "cmd", language: "sql", command: command.squeeze(' ') } }
       execute o_class: name, transaction: false do 
        [ { type: "cmd", language: 'sql', command:  "create class #{name} extends #{superclass}"} ]
       end
      end
      REST::Model.orientdb_class( name: name)
    end

=begin
nexus_edge connects two documents/vertexes 
The parameter o_class can be either a class or a string
=end

    def nexus_edge o_class: , attributes: {}, from:,  to:

      translate_to_rid = ->(obj){ if obj.is_a?( REST::Model ) then obj.link else obj end }
      puts   "create edge #{class_name(o_class)} from #{translate_to_rid[from]} to #{translate_to_rid[to]} "
      response=  execute( o_class: o_class, transaction: false) do 
      #[ { type: "cmd", language: 'sql', command:  CGI.escapeHTML("create edge #{class_name(o_class)} from #{translate_to_rid[from]} to #{translate_to_rid[to]}; ")} ]
      [ { type: "cmd", language: 'sql', 
	  command:  "create edge #{class_name(o_class)} from #{translate_to_rid[from]} to #{translate_to_rid[to]} "} ]
       end
       if response.is_a?(Array) && response.size == 1
	 response.pop # RETURN_VALUE
       else
	 response
       end
    end

=begin
Deletes a single edge  when providing a single rid-link (#00:00)
Deletes multible edges when providing a list of rid-links
Todo: implement delete_edges after querying the database in one statement

=end
    def delete_edge *rid

      response=  execute transaction: false do 
      [ { type: "cmd", language: 'sql', command:  CGI.escapeHTML("delete edge #{rid.join(',') }")} ]
       end
       if response.is_a?( Array ) && response.size == 1
	 response.pop # RETURN_VALUE
       else
	 response
       end
    end
=begin
deletes the database and returns true on success

after the removal of the database, the working-database might be empty

todo: remove all instances of the class 
=end
    def delete_class o_class
      cl= class_name(o_class)
      logger.progname = 'OrientDB#DeleteClass'
      
      begin
	response = @res[class_uri{ cl } ].delete
	if response.code == 204
	  # return_value: sussess of the removal
	  !database_classes( requery: true).include?(cl)
	  # don't delete the ruby-class
	  #	   REST::Model.send :remove_const, cl.to_sym if o_class.is_a?(Class)
	end
      rescue RestClient::InternalServerError => e
	if database_classes( requery: true).include?( cl )
	  logger.error{ "Class #{cl} still present" }
	  logger.error{ e.inspect }
	  false
	else
	  true
	end
      end

    end

    def create_property o_class:, field:, type: 'string', other_class: nil
      logger.progname= 'OrientDB#CreateProperty'
      begin
	last_argument = if other_class.present?
			  "/#{class_name(other_class)}"
			else 
			  ""
			end
      response = @res[ property_uri(class_name(o_class)){ field +'/'+type.upcase + last_argument } ].post ''
      if response.code == 201
        response.body.to_i
      else
	0
      end
      rescue RestClient::InternalServerError => e
	logger.error { "Property #{field} was NOT created" }
	logger.error { e.response }
	nil
      end

    end
## -----------------------------------------------------------------------------------------
##          
##  Properties
##  
##  create_properties
##  get_class_properties
##  delete_properties
##
## -----------------------------------------------------------------------------------------
=begin

creates properties which are defined as json in the provided block as
       create_properties( class_name: classname ) do
               { symbol: { propertyType: 'STRING' },
                 con_id: { propertyType: 'INTEGER' } ,
                details: { propertyType: 'LINK', linkedClass: 'Contracts' }
	        }

=end
    def create_properties o_class:
      logger.progname= 'OrientDB#CreateProperty'

      begin
	all_properties_in_a_hash =  yield
	if all_properties_in_a_hash.is_a? Hash
	  response = @res[ property_uri(class_name(o_class)) ].post all_properties_in_a_hash.to_json
	  if response.code == 201
	    response.body.to_i
	  else
	    0
	  end
	end
      rescue RestClient::InternalServerError => e
	logger.error { "Properties in #{class_name(o_class)} were NOT created" }
	logger.error { e.response}
	nil
      end

    end

    def delete_property o_class:, field:
          logger.progname = 'OrientDB#DeleteProperty'
       begin
	 response = @res[property_uri( class_name(o_class)){ field } ].delete
	 true if response.code == 204
       rescue RestClient::InternalServerError => e
	 logger.error{ "Property #{ field } in  class #{ class_name(o_class) } NOT deleted" }
	 false
       end

    end

    def get_class_properties o_class:
      response = JSON.parse( @res[ class_uri{ class_name(o_class) } ].get )
    end
    #
## -----------------------------------------------------------------------------------------
##          
##  Documents
##  
##  create_document                      get_document		delete_document
##  update_or_create_document            patch_document
##
##
##  get_documents
##  update_documents
##  delete_documents 
##  update_or_create_documents
## -----------------------------------------------------------------------------------------

    def create_document o_class:, attributes: {}
      attributes = yield if attributes.empty? && block_given?
      post_argument = { '@class' => class_name(o_class) }.merge attributes
      response = @res[ document_uri ].post post_argument.to_json
      o_class.new JSON.parse( response.body)
    end


    def delete_document record_id
          logger.progname = 'OrientDB#DeleteDocument'
       begin
	 response = @res[document_uri{ record_id } ].delete
	 true if response.code == 204
       rescue RestClient::InternalServerError => e
	 logger.error{ "Document #{ record_id }  NOT deleted" }
	 false
       end

    end
=begin
retrieves documents from a query

If raw is specified, the JSON-Array is returned, eg
  { "@type"=>"d", 
    "@rid"=>"#15:1", 
    "@version"=>1, 
    "@class"=>"DocumebntKlasse10", 
    "con_id"=>343, 
    "symbol"=>"EWTZ"
  }
otherwise a ActiveModel-Instance of o_class  is created and returned
=end

    def get_documents o_class:, where: {} , raw: false, limit: -1, ignore_block: false

        select_string =  'select from ' << class_name(o_class) 
	where_string =  compose_where( where )
	#
	# a block can be provided to extract the sql-statements prior to their execution
	yield( select_string + where_string ) if block_given? #&& !ignore_block
	url=  query_sql_uri << select_string << where_string  << "/#{limit}" 
	response =  @res[URI.encode(url) ].get
      r=JSON.parse( response.body )['result'].map do |document |
	  if raw then document else  o_class.new( document ) end
	end

    end


    def count_documents o_class: , where: {}

	url=  query_sql_uri << "select COUNT(*) from #{class_name(o_class)} " << compose_where( where ) 
	puts "url: #{url}"
	result =  JSON.parse( @res[URI.encode(url) ].get )['result']
	result.first['COUNT']

    end

=begin
Inserts a Document with the attributes provided in the attributes-hash
eg
   create_document class_name: @classname, attributes: { con_id: 343, symbol: 'EWTZ' }

   untested: for hybrid and schema-less documents the following syntax is supported
  create_document class_name: "Account", 
		  attributes: { date: 1350426789, amount: 100.34,
			       "@fieldTypes" => "date=t,amount=c" }

     The supported special types are:
n
      'f' for float
      'c' for decimal
      'l' for long
      'd' for double
      'b' for byte and binary
      'a' for date
      't' for datetime
      's' for short
      'e' for Set, because arrays and List are serialized as arrays like [3,4,5]
      'x' for links
      'n' for linksets
      'z' for linklist
      'm' for linkmap
      'g' for linkbag

=end

=begin 
UpdateOrCreateDocument

Based on the query specified in :where records are updated according to :set

Returns an Array of updated documents 
=end
    def create_or_update_document o_class: , set: {}, where:{}, &b
      logger.progname =  'Rest#CreateOrUpdateDocument'
      r= update_or_create_documents o_class: o_class, set: set, where:  where, &b
      if r.size > 1
	logger.error { "multible documents updated by #{ generate_sql_list( where )}" }
      end
      r.first  # return_value
    end
    def update_or_create_documents o_class: , set: {}, where: {} , &b
      logger.progname =  'Rest#UpdateOrCreateDocuments'
      if where.blank?
	[ create_document( o_class: o_class, attributes: set ) ]
      else
	set.extract!( where.keys ) # removes any keys from where in set
	possible_documents = get_documents( o_class: o_class, where: where, ignore_block: true)
	if possible_documents.empty?
	  if block_given?
	    more_where =   yield   # do Preparations prior to the creation of the dataset
    			      # if the block returns a Hash , it is merged into the insert_query.
	    where.merge! more_where if more_where.is_a?(Hash)
	  end
	  [ create_document( o_class: o_class, attributes: set.merge(where) )  ]
	else 
	    possible_documents.map{| doc | doc.update( set: set ) }
	end
      end
    end
=begin
Deletes  documents.
They are defined by a query. All records which match the attributes are deleted.
An Array with freed index-values is returned
=end
    def delete_documents o_class:, where: {}
       get_documents( o_class: o_class, where: where).map do |doc|
	 if doc['@type']=='d'  # document
	   index = doc['@rid'][1,doc['@rid'].size] # omit the first character ('#')
	   r=@res[ document_uri{ index  }].delete
	 index if  r.code==204 && r.body.empty? # return_value
	 end

       end
      
    end
=begin
Retrieves a Document from the Database as REST::Model::{class} 
The argument can either be a rid (#[x}:{y}) or a link({x}:{y}) 
If no Document  is found, nil is returned
=end
    def get_document rid, without_links: false

      rid = rid[1 .. rid.length] if rid[0]=='#'

      response = @res[ document_uri { rid } ].get 

      raw_data = JSON.parse( response.body).merge( "#no_links" => "#no_links" )
      REST::Model.orientdb_class( name: raw_data['@class']).new raw_data
      
    rescue RestClient::InternalServerError => e
	if e.http_body.split(':').last =~ /was not found|does not exist in database/
	  nil
	else
	  puts e.http_body.inspect
	  raise
	end
    end
=begin
Lazy Updating of the given Document.
=end
    def patch_document rid
      @res[ document_uri { rid } ].patch yield.to_json
    end


=begin
Updates the database in a oldschool-manner

  update_documents class_name: @classname,
          set: { :symbol => 'TWR' },
          where: { con_id: 340 }
   
replaces the symbol to TWS in each record where the con_id is 340 
Both set and where take multible attributes
returns the JSON-Response.

=end


    def update_documents o_class:, set: , where: {}
      url = "update #{class_name(o_class)}  set "<< generate_sql_list(set) << compose_where(where)
      response = @res[ URI.encode( command_sql_uri << url) ].post '' #url.to_json 
    end

## -----------------------------------------------------------------------------------------
##          
##  Functions and Batch
##  
##
## -----------------------------------------------------------------------------------------

=begin
Execute a predefined Function
=end
    def call_function    *args
puts "uri:#{function_uri { args.join('/') } }"
      @res[ function_uri { args.join('/') } ].post ''
    rescue RestClient::InternalServerError => e
	puts  JSON.parse(e.http_body)
    end


=begin
Executes a list of commands and returns the result-array (if present)

structure of the provided block:
[{ type: "cmd",
   language: "sql",
   command: "create class Person extends V"
   }, 
   (...)
 ]

 It's used by REST::Query.execute_queries

=end
    def execute  transaction: true, o_class: 'Myquery'
      batch =  { transaction: transaction, operations: yield }
      response = @res[ batch_uri ].post batch.to_json
      if response.code == 200
	if response.body['result'].present?
	 result= JSON.parse(response.body)['result']
	 result.map do |x| 
	   if x.is_a? Hash 
	     if x.has_key?('@class')
		REST::Model.orientdb_class( name: x['@class']).new x
	     elsif x.has_key?( 'value' )
	       x['value']
	     else
	       puts "o_class: #{o_class.inspect}"
		REST::Model.orientdb_class( name: class_name(o_class)).new x
	       
	     end
	   end
	 end.compact # return_value

	else
	  response.body
	end
      else
	nil
      end
    end
#private 
    def class_name  name_or_class
      if name_or_class.is_a? Class
	name_or_class.to_s.split('::').last
      elsif name_or_class.is_a? REST::Model
	name_or_class.classname
      else
	name_or_class
      end
    end
    def compose_where arg
      if arg.blank?
	   ""
	 elsif arg.is_a? String
	   if arg =~ /[w|W]here/
	     arg
	   else
	     "where "+arg
	   end
	 elsif arg.is_a? Hash
	   " where " + generate_sql_list(arg)
	 end
    end

    def generate_sql_list attributes={}
      attributes.map do | key, value |
	case value
	when Numeric
	  key.to_s << " = " << value.to_s 
	else #  String, Symbol
	  key.to_s << ' = ' << "\'#{ value }\'"
#	else 
#	  puts "ERROR, value-> #{value}, class -> #{value.class}"
	end
      end.join( ' and ' )

    end

      def property_uri(this_class_name)
	if block_given?
	"property/#{ @database }/#{this_class_name}/" <<  yield
	else
	"property/#{ @database }/#{this_class_name}"
	end
      end
# called in the beginning or after a 404-Error
      def get_ressource
	read_yml = ->( key ){ YAML::load_file( File.expand_path('../../config/connect.yml',__FILE__))[:orientdb][key] }
	login = read_yml[ :admin ].values 
	server_adress = read_yml[ :server ] + ":" + read_yml[ :port ].to_s 
	RestClient::Resource.new('http://' << server_adress, *login )
      end

def  self.simple_uri *names
     names.each do | name |
       m_name = (name.to_s << '_uri').to_sym
       define_method(  m_name  ) do | &b |
	 if b
	   "#{name.to_s}/"<< @database  << "/" <<  b.call
	 else
	   "#{name.to_s}/"<< @database 
	 end # branch
       end # def
     end
end

def self.sql_uri *names
    names.each do | name |
      define_method ((name.to_s << '_sql_uri').to_sym) do  
		    "#{name.to_s}/" << @database  << "/sql/" 
      end
    end
end

    simple_uri :database, :document, :class, :batch, :function
    sql_uri :command , :query



end # class
end # module
__END__

