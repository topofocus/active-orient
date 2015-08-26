module ActiveOrient
require 'cgi'
require 'rest-client'
require 'active_support/core_ext/string'  # provides blank?, present?, presence etc
#require 'model'
=begin
OrientDB performs queries to a OrientDB-Database

The communication is based on the ActiveOrient-API.

The OrientDB-Server is specified in config/connect.yml

A Sample:
 :orientdb:
   :server: localhost
     :port: 2480
   :database: working-database
   :admin:
     :user: admin-user 
     :pass: admin-password


=end

class OrientDB
  mattr_accessor :logger  ## borrowed from active_support
  mattr_accessor :default_server  ## 
  ## expected 
  # ActiveOrient::OrientDB.default_server = { server: 'localhost', port: 2480, user: '**', password: '**', database: 'temp'
  include OrientSupport::Support

=begin
Contructor: OrientDB is conventionally initialized. 
Thus several instances pointing to the same or different databases can coexist 

A simple 
 xyz =  ActiveOrient::OrientDB.new
uses the database specified in the yaml-file »config/connect.yml« and connects 
 xyz = ActiveOrient::OrientDB.new database: my_fency_database
accesses the database »my_fency_database«. The database is created if its not existing.

*USECASE*
 xyz =  ActiveOrient::Model.orientdb = ActiveOrient::OrientDB.new 
initialises the Database-Connection and publishes the Instance to any ActiveOrient::Model-Object
=end


  def initialize database: nil,  connect: true
    self.default_server = { :server => 'localhost', :port => 2480, :protocol => 'http', 
			    :user => 'root', :password => 'root', :database => 'temp' }.merge default_server
    @res = get_ressource
    @database = database.presence || default_server[:database]
    self.logger = Logger.new('/dev/stdout') unless logger.present?
#    @database=@database#.camelcase
    connect() if connect
    # save existing classes 
    @classes = []
    ActiveOrient::Model.orientdb =  self
  end

##  included for development , should be removed in production release  
  def ressource
    @res
  end
## 

# called in the beginning or after a 404-Error
def get_ressource
  login = [ default_server[:user].to_s , default_server[:password].to_s ] 
  server_adress = [ default_server[:protocol] ,"://" , default_server[ :server ],  ":" , default_server[ :port ]].map(&:to_s).join('')
  RestClient::Resource.new( server_adress, *login )
end

  def connect 
    i = 0
    begin
      logger.progname = 'OrientDB#Connect'
      r= @res["/connect/#{ @database }" ].get
      if r.code == 204 
	logger.info{ "Connected to database #{@database} " }
	true 
	else
	logger.error{ "Connection to database #{@database}  could NOT be established" }
	 nil 
	end
    rescue RestClient::Unauthorized => e
      if i.zero?
	logger.info{ "Database #{@database} NOT present --> creating" }
	i=i+1
	create_database
	retry
      else
	Kernel.exit
      end
    end

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
returns an Array with available Database-Names as Elements
=end
    def get_databases
       JSON.parse( @res["/listDatabases"].get.body)['databases']
    end

=begin
Creates a database with the given name and switches to this database as working-database
Types are either 'plocal' or 'memory' 

returns the name of the working-database
=end
    def create_database type: 'plocal' , database: @database 
      logger.progname = 'OrientDB#CreateDatabase'
	  old_d = @database
	  @classes = []
	  @database = database
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
    def delete_database database:
      @classes = []
      logger.progname = 'OrientDB#DropDatabase'
       old_ds =  @database
       change_database database
       begin
	 response = @res[database_uri].delete
	 if database == old_ds
	   change_database ""
	   logger.info{ "Working database deleted" }
	 else
	   change_database old_ds
	   logger.info{ "Database #{database} deleted, working database is still #{@database} "}
	 end
       rescue RestClient::InternalServerError => e
	 logger.info{ "Database #{database} NOT deleted" }
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
returns an Array with (unmodified) Class-attribute-hash-Elements

  get_classes 'name', 'superClass'
  returns
    [ {"name"=>"E", "superClass"=>""}, 
    {"name"=>"OFunction", "superClass"=>""}, 
    {"name"=>"ORole", "superClass"=>"OIdentity"}
    (...)
  ]
=end

    def get_classes *attributes
      i = 0
      begin
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
      rescue JSON::ParserError
	if i.zero?
	  i = i + 1
	  retry
	else
	  raise
	end
      end

    end
=begin
returns the class_hierachie

to fetch all Vertices
 class_hiearchie( base_class: 'V').flatten
to fetch all Edges
 class_hierachie( base_class: 'E').flatten

Notice: base_class has to be noted as String! There is no implicit conversion from Symbol or Class
=end

    def class_hierachie base_class: '', requery: false
      @all_classes =  get_classes( 'name', 'superClass') if requery || @all_classes.blank?
      def fv s   # :nodoc:
	 @all_classes.find_all{ |x| x[ 'superClass' ]== s }.map{| v| v[ 'name' ]} #.camelize } 
      end

      def fx v # :nodoc:
	fv(v).map{ |x| ar =  fx( x ) ; ar.empty? ? x :  [ x , ar  ] }
      end
  
      fx base_class
    end
=begin
returns an array with all names of the classes of the database
caches the result.

parameter: include_system_classes: false|true, requery: false|true
=end
    def database_classes include_system_classes: false, requery: false
      requery =  true if @classes.empty?
      if requery
	class_hierachie  requery: true
	system_classes = ["OFunction", "OIdentity", "ORIDs", "ORestricted", "ORole", "OSchedule", "OTriggered", "OUser", "_studio"]
	all_classes = get_classes( 'name' ).map( &:values).flatten
	@classes = include_system_classes ? all_classes : all_classes - system_classes 
      end
      @classes 
    end

    alias inspect_classes database_classes 
    
=begin
Creates classes and class-hierachies in OrientDB and in Ruby. 


Takes an Array or a Hash as argument and returns an Array of
successfull allocated Ruby-Classes

If the argument is an array,  Basic-Classes are build.

Otherwise  key/value pairs are assumend to follow this terminology
 { SuperClass => [ class, class, ...], SuperClass => [] , ... }
=end

    def create_classes classes
      # rebuild cashed classes-array
      # first the classes-string is camelized (this is used to allocate the ruby-class)
      # Then the database is queried for this string or the underscored string-variant 
      # the name-building process is independend from the method »class_name«
      database_classes requery: true
      consts = Array.new
      execute  transaction: false do 
	  class_cmd = ->(s,n) do
	    n = n.to_s.camelize
	    consts << ActiveOrient::Model.orientdb_class( name: n)
	    unless database_classes.include?(n) || database_classes.include?(n.underscore)
	    { type: "cmd", language: 'sql', command:  "create class #{n} extends #{s}"  } 

	    end 
	  end  ## class_cmd
	  
	  if classes.is_a?(Array)
	    classes.map do | n |
	    n = n.to_s.camelize # capitalize
	      consts << ActiveOrient::Model.orientdb_class( name: n)
	      unless database_classes.include?( n ) || database_classes.include?(n.underscore)
		{ type: "cmd", language: 'sql', command:  "create class #{n} " } 
	      end
	    end
	  elsif classes.is_a?(Hash)
	    classes.keys.map do | superclass | 
	      items =  Array.new
	      superClass =  superclass.to_s.camelize
	      items <<  { type: "cmd", language: 'sql', command:  "create class #{superClass} abstract" }  unless  database_classes.flatten.include?( superClass ) || database_classes.flatten.include?( superClass.underscore ) 
	      items << if classes[superclass].is_a?( String ) || classes[superclass].is_a?( Symbol )
		class_cmd[superClass, classes[superclass] ]
	      elsif  classes[superclass].is_a?( Array )  
		classes[superclass].map{|n| class_cmd[superClass, n] }
	      end 
	      #puts items.flatten.map{|x| x[:command]}
	      items  # returnvalue
	    end.flatten 
	  end.compact # erase nil-entries, in case the class is already allocated
      end
      # refresh cached class-informations
      database_classes requery: true
      # returns an array of allocated Constants/Classes
       consts
    end

=begin
creates a class and returns the a ActiveOrient::Model:{Newclass}-Class- (Constant)
which is designed to take any documents stored in this class

Predefined attributes: version, cluster, record

Other attributes are assigned dynamically upon reading documents

The classname is Camelized  by default, eg: classnames are always Capitalized, underscores ('_') indicate
that the following letter is capitalized, too.

Other class-names can be used if a "$" is placed at the begining of the name-string. However, most of the
model-based methods will not work in this case.
=end
    def create_class   newclass
      create_classes( [ newclass ] ).first
    end

    alias open_class create_class

    def create_vertex_class name , superclass: 'V'
      create_classes( { superclass => name } ).first
    end

    def create_edge_class name , superclass: 'E'
      create_classes( { superclass => name } ).first
    end

=begin
nexus_edge connects two documents/vertexes 
The parameter o_class can be either a class or a string
=end

    def nexus_edge o_class , attributes: {}, from:,  to:, unique: false
      logger.progname = "ActiveOrient::OrientDB#NexusEdge"
      if unique
	wwhere = { out: from.to_orient,  in: to.to_orient }.merge(attributes.to_orient) 
	existing_edge = get_documents( from: o_class, where: wwhere )
	if  existing_edge.first.is_a?( ActiveOrient::Model )
	  logger.debug { "reusing  edge #{class_name(o_class)} from #{from.to_orient} to #{to.to_orient} " }
	return existing_edge.first  
	end
      end
      logger.debug { "creating edge #{class_name(o_class)} from #{from.to_orient} to #{to.to_orient} " }
      response=  execute( o_class, transaction: false) do 
      #[ { type: "cmd", language: 'sql', command:  CGI.escapeHTML("create edge #{class_name(o_class)} from #{translate_to_rid[m]} to #{to.to_roient}; ")} ]
      attr_string =  attributes.blank? ? "" : "set #{ generate_sql_list attributes.to_orient }"
      [ { type: "cmd", language: 'sql', 
	  command:  "create edge #{class_name(o_class)} from #{from.to_orient} to #{to.to_orient} #{attr_string}"} ]
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
      rid =  rid.map do |mm|
	if mm.is_a?(String)
	  if mm.rid?
	    mm
	  elsif mm.is_a?(Rest::Model)
	    mm.rid
	  else
	    nil
	  end
	end
      end.compact
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
deletes the specified class and returns true on success


todo: remove all instances of the class 
=end
    def delete_class o_class
      cl= class_name(o_class)
      logger.progname = 'OrientDB#DeleteClass'
	
      if database_classes.include? cl
      begin
	response = @res[class_uri{ cl } ].delete
	if response.code == 204
	  # return_value: sussess of the removal
	  !database_classes( requery: true ).include?(cl)
	  # don't delete the ruby-class
	  #	   ActiveOrient::Model.send :remove_const, cl.to_sym if o_class.is_a?(Class)
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
      else
	logger.info { "Class #{cl} not present. "}
      end

    end
=begin
create a single property on class-level.

supported types: https://orientdb.com/docs/last/SQL-Create-Property.html

if index is to be specified, it's defined in the optional block 
  create_property(class, field){ :unique | :notunique }	                    --> creates an automatic-Index  on the given field
  create_property( class, field){ { »name«  =>  :unique | :notunique | :full_text } }  --> creates a manual index  

=end
    def create_property o_class, field, index: nil,  **args 
      logger.progname= 'OrientDB#CreateProperty'
	c= create_properties o_class,   {field =>  args} # translate_property_hash( field, args ) 
	if index.nil? && block_given?
	  index = yield
	end
	if c==1 && index.present? 
	  if index.is_a?( String ) || index.is_a?( Symbol ) 
	    create_index o_class, name: field, type: index
	  elsif index.is_a? Hash
	    bez= index.keys.first
#	    puts "index: #{index.inspect}"
#	    puts "bez: #{bez} ---> #{index.keys.inspect}"
	    create_index o_class, name: bez, type: index[bez], on: [ field ]
	  end
	end

    end


    def create_index o_class  , name:, on: :automatic, type: :unique 

      execute  transaction: false do 
	c =  class_name o_class
	command = if on == :automatic
		    "create index #{c}.#{name} #{type.to_s.upcase}"
		  elsif on.is_a? Array
		    "create index #{name} on #{class_name(o_class)}( #{on.join(', ')}) #{type.to_s.upcase}"
		  else 
		    nil
		  end
	[	{ type: "cmd", language: 'sql', command:  command  }  ]
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
private
def translate_property_hash  field, type: nil, linked_class: nil, **args
	type =  type.presence ||  args[:propertyType].presence || args[:property_type]
	linked_class = linked_class.presence || args[:linkedClass]
	if type.present?
	  if linked_class.nil?
	    { field => { propertyType: type.to_s.upcase } }
	  else
	    { field => { propertyType: type.to_s.upcase,  linkedClass: class_name( linked_class ) } }
	  end
	end

end
public
=begin

creates properties and optional an associated index as defined  in the provided block 

  create_properties( classname or class, properties as hash ) { index }

The default-case
  
  create_properties( con_id: { type:  :integer },
		    details: { type:  :link, linked_class: 'Contracts' } ) do
						 contract_idx: :notunique 
									  end

A composite index

  create_properties( con_id: { type: :integer },
		      symbol: { type: :string } ) do
	  		{ name: 'indexname',
			 on: [ :con_id , :details ]    # default: all specified properties
			 type: :notunique              # default: :unique
	        }
		end

=end
    def create_properties o_class, all_properties, &b

      all_properties_in_a_hash  =  HashWithIndifferentAccess.new
      all_properties.each{| field, args |  all_properties_in_a_hash.merge! translate_property_hash( field, args ) }

      begin
	count = if all_properties_in_a_hash.is_a?( Hash )
	  response = @res[ property_uri(class_name(o_class)) ].post all_properties_in_a_hash.to_json
	  if response.code == 201
	    response.body.to_i
	  else
	    0
	  end
	end
      rescue RestClient::InternalServerError => e
	response = JSON.parse( e.response)['errors'].pop
	error_message  = response['content'].split(':').last
#	if error_message ~= /Missing linked class/
	logger.progname= 'OrientDB#CreatePropertes'
	logger.error { "Properties in #{class_name(o_class)} were NOT created" }
	logger.error { "Error-code #{response['code']} --> #{response['content'].split(':').last }" }
	nil
      end
      ### index
      if block_given?   && count == all_properties_in_a_hash.size
	index =  yield
	if index.is_a?( Hash ) 
	  if index.size == 1
	    create_index o_class, name: index.keys.first, on: all_properties_in_a_hash.keys, type: index.values.first
	  else
	    index_hash =  HashWithIndifferentAccess.new( type: :unique, on: all_properties_in_a_hash.keys ).merge index
	    create_index o_class, index_hash # i [:name], on: index_hash[:on], type: index_hash[:type]
	  end
	end
      end
      count  # return_value
    end

    def delete_property o_class, field
          logger.progname = 'OrientDB#DeleteProperty'
       begin
	 response = @res[property_uri( class_name(o_class)){ field } ].delete
	 true if response.code == 204
       rescue RestClient::InternalServerError => e
	 logger.error{ "Property #{ field } in  class #{ class_name(o_class) } NOT deleted" }
	 false
       end

    end

    def get_class_properties o_class   #  :nodoc:
      JSON.parse( @res[ class_uri{ class_name(o_class) } ].get )
    end

    def print_class_properties o_class
      puts "Detected Properties for class #{class_name(o_class)}"

      rp = get_class_properties o_class 
      n=  rp['name']
      puts rp['properties'].map{|x| [ n+'.'+x['name'], x['type'],x['linkedClass'] ].compact.join(' -> ' )}.join("\n")

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

=begin #nodoc#
If properties are allocated on class-level, they can be preinitialized using
this method.
This is disabled for now, because it does not seem nessesary

=end
def preallocate_class_properties o_class
  p= get_class_properties( o_class )['properties']
  unless p.nil? || p.blank?
      predefined_attributes = p.map do | property |
	[ property['name'] ,
	case property['type']
	when 'LINKMAP'
	  Array.new
	when 'STRING'
	  ''
	else
	  nil
	end  ]
      end.to_h
  else
    {}
  end
end

=begin
Creates an Object in the Database and returns this as ActuveOrient::Model-Instance
=end

    def create_document o_class, attributes: {}
      attributes = yield if attributes.empty? && block_given?
#      preallocated_attributes =  preallocate_class_properties o_class
#      puts "preallocated_attributes: #{o_class} -->#{preallocated_attributes.inspect }"
      post_argument = { '@class' => class_name(o_class) }.merge(attributes).to_orient
#	puts "post_argument: #{post_argument.inspect}"
	
      response = @res[ document_uri ].post post_argument.to_json
      data= JSON.parse( response.body )
#    data = preallocated_attributes.merge data
      ActiveOrient::Model.orientdb_class( name: data['@class']).new data
#      o_class.new JSON.parse( response.body)
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
def get_documents  limit: -1, raw: false, query: nil, **args 
  query =  OrientSupport::OrientQuery.new(  args ) if query.nil?
  i=0
 begin
   url =    query_sql_uri << query.compose << "/#{limit}" 
   response =  @res[URI.encode(url) ].get
   r=JSON.parse( response.body )['result'].map do |document |
     if raw 
       document 
     else  
       ActiveOrient::Model.orientdb_class( name: document['@class']).new document
     end
   end
 rescue RestClient::InternalServerError => e
  response = JSON.parse( e.response)['errors'].pop
  logger.error { response['content'].split(':').last  }
  i=i+1
  if i > 1
    raise
  else
    query.dataset_name = query.datatset_name.underscore
    logger.info { "trying to query using #{o_class}" }
    retry
  end
end

end

    def count_documents **args
      logger.progname = 'OrientDB#count_documents'

	query =  OrientSupport::OrientQuery.new args
	query.projection 'COUNT (*)'
	result = get_documents raw: true, query: query 

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
Creating a new Database-Entry ( where is omitted )

otherwise updating the Database-Entry (if present)

The optional Block should provide a hash with attributes(properties). These are used if
a new dataset is created.
=end
    def create_or_update_document o_class , **args, &b
      logger.progname =  'Rest#CreateOrUpdateDocument'
      r= update_or_create_documents o_class, **args, &b
      if r.size > 1
	logger.error { "multible documents updated by #{ generate_sql_list( where )}" }
      end
      r.first  # return_value
    end
=begin 
Based on the query specified in :where records are updated according to :set

Returns an Array of updated documents 

The optional Block should provide a hash with attributes(properties). These are used if
a new dataset is created.

### das ist noch nicht rund.
#
=end
    def update_or_create_documents o_class , set: {}, where: {} , **args , &b
      logger.progname =  'Rest#UpdateOrCreateDocuments'
      if where.blank?
	[ create_document( o_class, attributes: set ) ]
      else
	set.extract!( where.keys ) # removes any keys from where in set
	possible_documents = get_documents from: class_name( o_class ), where: where,  **args
	if possible_documents.empty?
	  if block_given?
	    more_where =   yield   # do Preparations prior to the creation of the dataset
    			      # if the block returns a Hash , it is merged into the insert_query.
	    where.merge! more_where if more_where.is_a?(Hash)
	  end
	  [ create_document( o_class, attributes: set.merge(where) )  ]
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
    def delete_documents o_class, where: {}
       get_documents( from: o_class, where: where).map do |doc|
	 if doc['@type']=='d'  # document
	   index = doc['@rid'][1,doc['@rid'].size] # omit the first character ('#')
	   r=@res[ document_uri{ index  }].delete
	 index if  r.code==204 && r.body.empty? # return_value
	 end

       end
      
    end
=begin
Retrieves a Document from the Database as ActiveOrient::Model::{class} 
The argument can either be a rid (#[x}:{y}) or a link({x}:{y}) 
If no Document  is found, nil is returned

In the optional block, a subset of properties can be defined (as array of names)
=end
    def get_document rid

      rid = rid[1 .. rid.length] if rid[0]=='#'

      response = @res[ document_uri { rid } ].get 

      raw_data = JSON.parse( response.body) #.merge( "#no_links" => "#no_links" )
      ActiveOrient::Model.orientdb_class( name: raw_data['@class']).new raw_data
      
    rescue RestClient::InternalServerError => e
	if e.http_body.split(':').last =~ /was not found|does not exist in database/
	  nil
	else
	  logger.progname 'OrientDB#GetDocument'
	  logger.error "something went wrong"
	  logger.error e.http_body.inspect
	  raise
	end
    end
=begin
Lazy Updating of the given Document.
=end
    def patch_document rid
      logger.progname =  'Rest#PatchDocument'
      content = yield
      if content.is_a? Hash
      content.each do | key, value |
#	puts "content: #{key}, #{value.class}"
#	content[key]= value.to_orient #if value.is_a? ActiveOrient::Model
      end
      @res[ document_uri { rid } ].patch content.to_orient.to_json
      else
	logger.error { "FAILED: The Block must provide an Hash  with properties to be updated"}
      end
    end
=begin
  update_documents classname,
          set: { :symbol => 'TWR' },
          where: { con_id: 340 }
   
replaces the symbol to TWR in each record where the con_id is 340 
Both set and where take multible attributes
returns the JSON-Response.

=end


    def update_documents o_class, set: , where: {}
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
#puts "uri:#{function_uri { args.join('/') } }"
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

 It's used by ActiveOrient::Query.execute_queries

=end
    def execute classname = 'Myquery', transaction: true  
      batch =  { transaction: transaction, operations: yield }
      unless batch[:operations].blank?
#	puts "batch_uri: #{@res[batch_uri]}"
#        puts "post: #{batch.to_json}"
	response = @res[ batch_uri ].post batch.to_json 
	if response.code == 200
	  if response.body['result'].present?
	    result= JSON.parse(response.body)['result']
	    result.map do |x| 
	      if x.is_a? Hash 
		if x.has_key?('@class')
		  ActiveOrient::Model.orientdb_class( name: x['@class']).new x
		elsif x.has_key?( 'value' )
		  x['value']
		else
#		  puts "ActiveOrient::Execute"
#		  puts "o_class: #{o_class.inspect}"
		  ActiveOrient::Model.orientdb_class( name: classname).new x
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
    rescue RestClient::InternalServerError => e
      raise

    end
=begin
Converts a given name to the camelized database-classname

Converts a given class-constant to the corresponding database-classname

returns a valid database-class name, nil if the class not exists
=end
    def class_name  name_or_class
      name= if name_or_class.is_a? Class
	name_or_class.to_s.split('::').last
      elsif name_or_class.is_a? ActiveOrient::Model
	name_or_class.classname
      else
	name_or_class.to_s.camelize
      end
     if database_classes.include?(name) 
       name
     elsif database_classes.include?(name.underscore) 
       name.underscore
     else
       logger.progname =  'OrientDB#ClassName'
       logger.info{ "Classname #{name} not present in active  Database" }
       nil
     end
    end
#    def compose_where arg
#      if arg.blank?
#	   ""
#	 elsif arg.is_a? String
#	   if arg =~ /[w|W]here/
#	     arg
#	   else
#	     "where "+arg
#	   end
#	 elsif arg.is_a? Hash
#	   " where " + generate_sql_list(arg)
#	 end
#    end
private 

#def generate_sql_list attributes={}
#  attributes.map do | key, value |
#    case value
#    when Numeric
#      key.to_s << " = " << value.to_s 
#    else #  String, Symbol
#      key.to_s << ' = ' << "\'#{ value }\'"
#      #	else 
#      #	  puts "ERROR, value-> #{value}, class -> #{value.class}"
#    end
#  end.join( ' and ' )
#
#end
#
def property_uri(this_class_name)
  if block_given?
    "property/#{ @database }/#{this_class_name}/" <<  yield
  else
    "property/#{ @database }/#{this_class_name}"
  end
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

