module REST

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
      def initialize database: nil,  connect: true
	@res = get_ressource
	@database = database|| YAML::load_file( File.expand_path('../../config/connect.yml',__FILE__))[:orientdb][:database] 
	self.logger = logger	
	connect() if connect
      end

      def ressource
	@res
      end
    def connect 
      r= @res["/connect/#{ @database }" ].get
      r.code == 204 ? true : nil 
    end

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
      @database =  name

    end
=begin
deletes the database and returns true on success

after the removal of the database, the working-database might be empty
=end
    def delete_database name:
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

parameter: include_system_classes: false|true
=end
    def database_classes include_system_classes: false
      system_classes = ["OFunction", "OIdentity", "ORIDs", "ORestricted", "ORole", "OSchedule", "OTriggered", "OUser", "V", "_studio","E"]
      all_classes = get_classes( 'name' ).map( &:values).flatten
      include_system_classes ? all_classes : all_classes - system_classes 
    end
    
=begin
creates a class and returns the a REST::Model:{Newclass}-Class- (Constant)
which is designed to take any documents stored in this class

Predefined attributes: version, cluster, record
Other attributes are assigned dynamically upon reading documents
=end
    def create_class   newclass
      logger.progname= 'OrientDB#CreateClass'
      create_constant = ->(c){ "REST/Model/#{c}".camelize.constantize }
      create_model = ->(c){  REST::Model.orientdb_class name: c }
      begin
	response = @res[ class_uri{ newclass } ].post ''
	ror_class= REST::Model.orientdb_class( name: newclass)
	yield ror_class if block_given?   #  perform actions only if the class was sucessfully created
	ror_class # return_value
      rescue RestClient::InternalServerError => e
	# expected answer: {"errors"=>[{"code"=>500, "reason"=>500, "content"=>"java.lang.IllegalArgumentException: Class 'NeueKlasse10' already exists"}]}
	if  (ou=JSON.parse(e.http_body)['errors'].first['content']) =~ /already exists/
	  logger.info { ou.split(':').last }
	  REST::Model.orientdb_class( name: newclass)

#	  if ( REST::Model.send( :const_get, newclass.to_sym ) rescue nil )
#	    logger.info { "#{newclass} already initialized, reusing " }
#	    create_constant[  newclass ]
#	  else
#	    logger.info{  "#{newclass} not initialized! --> creating " }
#	    create_model[ newclass ]
#
#	  end
	else
	  logger.error { "Class #{newclass} was NOT created" }
	  nil
	end
      rescue NameError
	#  uninitialized constant, raised in  camelize.constantise
	create_model[ newclass ]

      end
    end
=begin
deletes the database and returns true on success

after the removal of the database, the working-database might be empty
=end
    def delete_class o_class
      class_name = if o_class.is_a? Class
		     o_class.to_s.split('::').last
		   else
		      o_class
		   end
          logger.progname = 'OrientDB#DeleteClass'
       begin
	 response = @res[class_uri{ class_name} ].delete
	 if response.code == 204
	   REST::Model.send :remove_const, class_name.to_sym if o_class.is_a?(Class)
	   true  # return_value
	 end
       rescue RestClient::InternalServerError => e
	 logger.info{ "Class #{class_name} NOT deleted" }
	 logger.info{ e.inspect }
	 false
       end

    end

    def create_property o_class:, field:, type: 'string'
      class_name = o_class.to_s.split('::').last
      logger.progname= 'OrientDB#CreateProperty'
      begin
      response = @res[ property_uri(class_name){ field +'/'+type.upcase  } ].post ''
      if response.code == 201
        response.body.to_i
      else
	0
      end
      rescue RestClient::InternalServerError => e
	logger.error { "Property #{name} was NOT created" }
	logger.error { e.response }
	nil
      end

    end
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
      class_name = o_class.to_s.split('::').last

      begin
	all_properties_in_a_hash =  yield
	if all_properties_in_a_hash.is_a? Hash
	  response = @res[ property_uri(class_name) ].post all_properties_in_a_hash.to_json
	  if response.code == 201
	    response.body.to_i
	  else
	    0
	  end
	end
      rescue RestClient::InternalServerError => e
	logger.error { "Properties in #{class_name} were NOT created" }
	logger.error { e.response}
	nil
      end

    end

    def delete_property o_class:, field:
      class_name = o_class.to_s.split('::').last
          logger.progname = 'OrientDB#DeleteProperty'
       begin
	 response = @res[property_uri( class_name){ field } ].delete
	 true if response.code == 204
       rescue RestClient::InternalServerError => e
	 logger.error{ "Property #{ field } in  class #{ class_name } NOT deleted" }
	 false
       end

    end

    def get_class_properties class_name:
      response = JSON.parse( @res[ class_uri{ class_name } ].get )
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
retrieves documents from the database
and returns an Array with entries like
  { "@type"=>"d", 
    "@rid"=>"#15:1", 
    "@version"=>1, 
    "@class"=>"DocumebntKlasse10", 
    "con_id"=>343, 
    "symbol"=>"EWTZ"
  }
=end

    def get_documents o_class:, where: {} , raw: false
      class_name = o_class.to_s.split('::').last


        select_string =  'select from ' << class_name 
	where_string =  if where.empty?
			  ""
			else 
			 " where " <<  generate_sql_list(where)
			end
	yield( select_string + where_string ) if block_given?

	url=  query_sql_uri << select_string << where_string 
	response =  @res[URI.encode(url) ].get
	r=JSON.parse( response.body )['result'].map do |document |
	  if raw then document else  o_class.new(	document	) end
	end

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

    def update_or_create_document o_class:, set: {}, where: {} 
      logger.progname =  'Rest#CreateOrUpdateDocument'
      if where.blank?
	create_document o_class: o_class, attributes: set
      else
	set.extract!( where.keys ) # removes any keys from where in set
	possible_documents = get_documents( o_class: o_class, where: where)
	if possible_documents.empty?
	  yield if block_given?  # do Preparations prior to the creation of the dataset
	  create_document( o_class: o_class) do
	    set.merge(where) 
	  end
	elsif possible_documents.size == 1
	        response = possible_documents.first.update( set: set )
		possible_documents.first #@res[ document_uri ].put post_argument.to_json
	else
	  logger.error{ "multible (#{possible_documents.size})records found for #{where.inspect}" }
	  puts "possible documents"
	  puts possible_documents.inspect

	end
      end
    end
=begin
Retrieves a Document from the Database as REST::Model::{class} 

=end
    def get_document rid
      response = @res[ document_uri { rid } ].get 

      raw_data = JSON.parse( response.body)
      REST::Model.orientdb_class( name: raw_data['@class']).new raw_data
    end
=begin
Lazy Updating of the given Document.
=end
    def patch_document rid
      @res[ document_uri { rid } ].patch yield.to_json
    end

    def call_function    *args
puts "uri:#{function_uri { args.join('/') } }"
      @res[ function_uri { args.join('/') } ].post ''
    rescue RestClient::InternalServerError => e
	puts  JSON.parse(e.http_body)
    end

    def create_document o_class:, attributes: {}
      class_name = o_class.to_s.split('::').last
      if attributes.empty?
#	vars = get_class_properties( class_name: class_name)[:properties].keys
	attributes = yield 
      end
      post_argument = { '@class' => class_name }.merge attributes
      response = @res[ document_uri ].post post_argument.to_json
      #puts "RESPONSE: #{ response.body } "
      #puts JSON.parse( response.body).inspect

      o_class.new JSON.parse( response.body)
    end

=begin
Deletes  documents.
They are defined by a query. All records which match the attributes are deleted.
An Array with freed index-values is returned
=end
    def delete_documents o_class:, where: {}
      class_name = o_class.to_s.split('::').last
       get_documents( o_class: o_class, where: where).map do |doc|
	 if doc['@type']=='d'  # document
	   index = doc['@rid'][1,doc['@rid'].size] # omit the first character ('#')
	   r=@res[ document_uri{ index  }].delete
	 index if  r.code==204 && r.body.empty? # return_value
	 end

       end
      
    end
=begin
Updates the database in a oldschool-manner

  update_documents class_name: @classname,
          set: { :symbol => 'TWR' },
          where: { con_id: 340 }
   
replaces the symbol to TWS in each record where the con_id is 340 
Both set and where take multible attributes
=end


    def update_documents o_class:, set: , where: {}
      class_name = o_class.to_s.split('::').last
      url = "update #{class_name}  set "<< generate_sql_list(set) << " where " << generate_sql_list(where)
      response = @res[ URI.encode( command_sql_uri << url) ].post '' #url.to_json 
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

=end
    def execute  transaction: true, class_name: 'Myquery'
      batch =  { transaction: transaction, operations: yield }
      response = @res[ batch_uri ].post batch.to_json
      if response.code == 200
	if response.body['result'].present?
	 result= JSON.parse(response.body)['result']
  
#	 o_class = if ( REST::Model.send( :const_get, class_name.to_sym  ) rescue nil )
#		     "REST/Model/#{class_name}".camelize.constantize 
#		    else
#		      REST::Model.orientdb_class name: class_name 
#		    end
	 result.map do |x| 
	   if x.is_a? Hash 
	     if x.has_key?('@class')
		REST::Model.orientdb_class( name: x['@class']).new x
	     elsif x.has_key?( 'value' )
	       x['value']
	     else
		REST::Model.orientdb_class( name: class_name).new x
	       
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
private 

    def generate_sql_list attributes={}
      attributes.map do | key, value |
	case value
	when Numeric
	  key.to_s << " = " << value.to_s 
	when String, Symbol
	  key.to_s << ' = ' << "\'#{ value }\'"
	end
      end.join( ' and ' )

    end

      def property_uri(class_name)
	if block_given?
	"property/#{ @database }/#{class_name}/" <<  yield
	else
	"property/#{ @database }/#{class_name}"
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

