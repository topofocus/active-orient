module REST

require 'rest-client'
require 'active_support/all'
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
      def initialize database: nil, logger: Logger.new(STDOUT), connect: true
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
creates a class and returns the cluster
=end
    def create_class   newclass
      logger.progname= 'OrientDB#CreateClass'
      begin
      response = @res[ class_uri{ newclass } ].post ''
      if response.code == 201
        response.body
      else
	0
      end
      rescue RestClient::InternalServerError => e
	logger.error { "Class #{newclass} was NOT created" }
	nil
      end
    end
=begin
deletes the database and returns true on success

after the removal of the database, the working-database might be empty
=end
    def delete_class class_name
          logger.progname = 'OrientDB#DeleteClass'
       begin
	 response = @res[class_uri{ class_name} ].delete
	 true if response.code == 204
       rescue RestClient::InternalServerError => e
	 logger.info{ "Class #{class_name} NOT deleted" }
	 false
       end

    end

    def create_property class_name:, field:, type: 'string'
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
	puts e.inspect
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
    def create_properties class_name:
      logger.progname= 'OrientDB#CreateProperty'

      begin
	attributes =  yield
      response = @res[ property_uri(class_name) ].post attributes.to_json
      if response.code == 201
        response.body.to_i
      else
	0
      end
      rescue RestClient::InternalServerError => e
	logger.error { "Properties in #{class_name} were NOT created" }
	logger.error { e.response}
	nil
      end

    end

    def delete_property class_name:, field:
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

    def get_documents class_name:, where: {}
        select_string =  'select from ' << class_name 
	where_string =  if where.empty?
			  ""
			else 
			 " where " <<  generate_sql_list(where)
			end

	  #puts "attributes: #{attributes.inspect}"
	  #puts "query: #{select_string+where_string}"
	url=  query_sql_uri << select_string << where_string 
	response =  @res[URI.encode(url) ].get
	#puts response.code
	JSON.parse( response.body )['result']

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

    def create_document class_name:, attributes: {}
      if attributes.empty?
	vars = get_class_properties( class_name: class_name)[:properties].keys
	attributes = yield vars
      end
      post_argument = { '@class' => class_name }.merge attributes
      response = @res[ document_uri ].post post_argument.to_json
      JSON.parse( response.body)
    end

=begin
Deletes  documents.
They are defined by a query. All records which match the attributes are deleted.
An Array with freed index-values is returned
=end
    def delete_documents class_name:, where: {}
       get_documents( class_name: class_name, where: where).map do |doc|
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


    def update_documents class_name:, set: , where: {}
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
    def execute  transaction: true
      batch =  { transaction: transaction, operations: yield }
      response = @res[ batch_uri ].post batch.to_json
      if response.code == 200
	if response.body['result'].present?
	  JSON.parse(response.body)['result']
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

    simple_uri :database, :document, :class, :batch
    sql_uri :command , :query


end # class
end # module
__END__

