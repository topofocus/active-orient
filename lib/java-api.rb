require 'orientdb'
require_relative "database_utils.rb" #common methods without rest.specific content
require_relative "class_utils.rb" #common methods without rest.specific content
require_relative "orientdb_private.rb" 


module ActiveOrient


  class API
    include OrientSupport::Support
    include DatabaseUtils
    include ClassUtils
    include OrientDbPrivate
    include OrientDB

    mattr_accessor :logger # borrowed from active_support
    attr_reader :database # Used to read the working database

    #### INITIALIZATION ####


    def initialize database: nil, connect: true, preallocate: true
      self.logger = Logger.new('/dev/stdout') unless logger.present?
      ActiveOrient.database= database if database.present?
      #puts   ["remote:#{default_server[:server]}/#{@database}",
#					default_server[:user], default_server[:password] ]
      connect() if connect
#      @db  =   DocumentDatabase.connect("remote:#{default_server[:server]}/#{@database}",
#					default_server[:user], default_server[:password] )
      ActiveOrient::Model.db = self 
      preallocate_classes  if preallocate

    end

    def db
      @db
    end

# Used for the connection on the server
    #

# Used to connect to the database

    def connect
      begin
      logger.progname = 'JavaApi#connect'
      @db  =   DocumentDatabase.connect("remote:#{ActiveOrient.default_server[:server]}/#{ActiveOrient.database}",
					ActiveOrient.default_server[:user], ActiveOrient.default_server[:password] )
      rescue Java::ComOrientechnologiesOrientCoreException::OConfigurationException => e
	  logger.fatal{ e.message}
	  logger.fatal{ "ServerAdim not implemented in ActiveOrient#JavaApi "}
#	  OrientDB::ServerAdmin("remote:localhost").connect( default_server[:user], default_server[:password] )
#	  OrientDB::ServerAdmin.createDatabase(@database, "document", "remote");
#	  OrientDB::ServerAdmin.close();
	  Kernel.exit
      end
      get_database_classes( requery:true ) # returns all allocated database_classes
    end

  

    def get_classes *attributes
      classes=  @db.metadata.schema.classes.map{|x| { 'name' => x.name , 'superClass' => x.get_super_class.nil? ? '': x.get_super_class.name } }
      unless attributes.empty?
	classes.map{|y| y.select{|v,_| attributes.include?(v)}}
      else
	classes
      end

    end


    def create_classes classes , &b
      consts = allocate_classes_in_ruby( classes , &b )

      all_classes = consts.is_a?( Array) ? consts.flatten : [consts]
      get_database_classes(requery: true)
      selected_classes =  all_classes.map do | this_class |
	this_class unless get_database_classes(requery: true).include?( this_class.ref_name ) rescue nil
      end.compact.uniq
      command= selected_classes.map do | database_class |
	## improper initialized ActiveOrient::Model-classes lack a ref_name class-variable
	next if database_class.ref_name.blank?  
	c = if database_class.superclass == ActiveOrient::Model || database_class.superclass.ref_name.blank?
	      puts "CREATE CLASS #{database_class.ref_name} "
	      OClassImpl.create @db, database_class.ref_name 
	    else
	      puts "CREATE CLASS #{database_class.ref_name} EXTENDS #{database_class.superclass.ref_name}"
	      OClassImpl.create @db, database_class.ref_name, superClass: database_class.superclass.ref_name 
	    end
      end

      # update the internal class hierarchy 
      get_database_classes requery: true
      # return all allocated classes, no matter whether they had to be created in the DB or not.
      #  keep the format of the input-parameter
      consts.shift if block_given? && consts.is_a?( Array) # remove the first element
      # remove traces of superclass-allocations
      if classes.is_a? Hash
	consts =  Hash[ consts ] 
	consts.each_key{ |x| consts[x].delete_if{|y| y == x} if consts[x].is_a? Array  }
      end
      consts
    end



    def delete_class o_class
      begin
      logger.progname = 'JavaApi#DeleteClass'
      @db.schema.drop_class classname(o_class)
      rescue Java::ComOrientechnologiesOrientCoreException::OSchemaException => e
	logger.error{ e.message }
      end
      get_database_classes requery: true 
    end
=begin
  Creates properties and optional an associated index as defined  in the provided block
    create_properties(classname or class, properties as hash){index}

  The default-case
    create_properties(:my_high_sophisticated_database_class,
  		con_id: {type: :integer},
  		details: {type: :link, linked_class: 'Contracts'}) do
  		  contract_idx: :notunique
  		end

  A composite index
    create_properties(:my_high_sophisticated_database_class,
  		con_id: {type: :integer},
  		symbol: {type: :string}) do
  	    {name: 'indexname',
  			 on: [:con_id, :details]    # default: all specified properties
  			 type: :notunique            # default: :unique
  	    }
  		end
=end

    def create_properties o_class, **all_properties, &b
      logger.progname = 'JavaApi#CreateProperties'
      ap =  all_properties
      created_properties = ap.map do |property, specification | 
	puts "specification:  #{specification.inspect}"
	field_type = ( specification.is_a?( Hash) ?  specification[:type] : specification ).downcase.to_sym rescue :string
	the_other_class =  specification.is_a?(Hash) ?  specification[:other_class] : nil
	other_class = if the_other_class.present? 
			@db.get_class( the_other_class)
		      end
	index =  ap.is_a?(Hash) ?  ap[:index] : nil
	if other_class.present?
	  @db.get_class(classname(o_class)).add property,[ field_type, other_class ], { :index => index }
	else
	  @db.get_class(classname(o_class)).add property, field_type, { :index => index }
	end
      end
      if block_given?
	attr =  yield
	index_parameters = case attr 
			   when String, Symbol
			     { name: attr }
			   when Hash
			     { name: attr.keys.first , type: attr.values.first, on: all_properties.keys.map(&:to_s) }
			   else
			     nil
			   end
	create_index o_class, **index_parameters unless index_parameters.blank?
      end
      created_properties.size # return_value

    end

    def get_properties o_class
      @db.get_class(classname(o_class)).propertiesMap
    end



    def create_index o_class, name:, on: :automatic, type: :unique
      logger.progname = 'JavaApi#CreateIndex'
      begin
	c = @db.get_class( classname( o_class ))
	index = if on == :automatic
		  nil   # not implemented
		elsif on.is_a? Array
		  c.createIndex name.to_s, INDEX_TYPES[type],  *on
		else
		  c.createIndex name.to_s, INDEX_TYPES[type],  on
		end
      end
    end

    def create_record o_class, attributes: {}
      logger.progname = 'JavaApi#CreateRecord'
      attributes = yield if attributes.empty? && block_given?
      new_record = insert_document( o_class, attributes.to_orient )


    end
    alias create_document create_record

    def upsert o_class, set: {}, where: {} 
      logger.progname = 'JavaApi#Upsert'
      if where.blank?
	new_record = create_record(o_class, attributes: set)
	yield new_record if block_given?	  # in case if insert execute optional block
	new_record			  # return_value
      else
	specify_return_value =  block_given? ? "" : "return after @this"
	set.merge! where if where.is_a?( Hash ) # copy where attributes to set 
	command = "Update #{classname(o_class)} set #{generate_sql_list( set ){','}} upsert #{specify_return_value}  #{compose_where where}" 
	result =  @db.run_command command

	case result
	when  Java::JavaUtil::ArrayList
	  update_document result[0]
	when ActiveOrient::Model
	  result   # just return the result
	when String, Numeric
	  the_record=  get_records(from: o_class, where: where, limit: 1).pop
	  if result.to_i == 1  # one dataset inserted, block is specified
	    yield the_record 	
	  end
	  the_record # return_value
	else
	  logger.error{ "Unexpected result form Query \n  #{command} \n Result: #{result}" }
	end
      end
    end
    def get_records raw: false, query: nil, **args
      query = OrientSupport::OrientQuery.new(args) if query.nil?
      logger.progname = 'JavaApi#GetRecords'
      result =  @db.custom query.compose
      result.map do |record|
	update_document record
      end
    end
    alias get_documents get_records


    def get_record rid
      logger.progname = 'JavaApi#GetRecord'
      rid = "#"+ rid unless rid[0]=='#'
      record = @db.custom "select from #{rid}"
      if record.count.zero?
	logger.error{ "No record found for rid= #{rid}" }
      else
	update_document record[0]
      end
    end


    def execute transaction: true, tolerated_error_code: nil # Set up for classes
      batch = {transaction: transaction, operations: yield}
      unless batch[:operations].blank?
	batch[:operations] = [batch[:operations]] unless batch[:operations].is_a? Array
	batch[:operations].map do |command_record|
	  puts command_record.inspect
	  response = @db.run_command  command_record.is_a?(Hash) ?  command_record[:command] : command_record 
	  if response.is_a? Fixnum
	    response
	  else
	    response.map do | r |
	       r.rid.rid? ?  update_document( r ) :  r.values
	    end
	  end
	end
      end
    end


    def delete_record  *object_or_rid
      object_or_rid.map do |o|
	d= if o.is_a?( String ) && o.rid?
	   @db.custom "select from #{o}"
	elsif o.is_a? ActiveOrient::Model
	   @db.custom "select from #{o.to_orient}"
	else
	    o
	end
	o.delete
      end
    end
    
private    def insert_document o_class, attributes
#      puts "insert_document"
 puts "o_class: #{o_class.inspect  }"
#      puts "classname: #{classname( o_class ) }"
#      puts "attributes: #{ attributes }"
#
      begin
	d = Document.new  classname(o_class)
	attributes.each{|y,x| d[y] = x}
	d.save
	update_document d
      rescue Java::ComOrientechnologiesOrientCoreException::OSchemaException => e
      logger.progname = 'JavaApi#InsertDocument'
	logger.error{ e }

	logger.error{ "Parameter: DB: #{@db.name}, Class: #{classname(o_class)} attributes: #{attributes.inspect}" }
	logger.error{ database_classes.inspect }
      end
    end
    #  returns a valid model-instance
    def update_document java_document
      if java_document.is_a? Document
      o_class =  java_document.class_name
      d =  java_document
      attributes = d.values
      ActiveOrient::Model.get_model_class(o_class).new attributes.merge( { "@rid" => d.rid,
								      "@version" => d.version,
								      "@type" => 'd',
								      "@class" => o_class } )
      else
      logger.progname = 'JavaApi#UpdateDocument'
	logger.error{ "Wrong Parameter: #{java_document.inspect} "}
      end
    end
  end
end
