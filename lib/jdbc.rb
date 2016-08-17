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
    mattr_accessor :default_server
    attr_reader :database # Used to read the working database

    #### INITIALIZATION ####


    def initialize database: nil, connect: true, preallocate: true
      self.logger = Logger.new('/dev/stdout') unless logger.present?
      self.default_server = {
        :server => 'localhost',
        :port => 2480,
        :protocol => 'http',
        :user => 'root',
        :password => 'root',
        :database => 'temp'
      }.merge default_server.presence || {}
      @database = database || default_server[:database]
      @all_classes=[]
      #puts   ["remote:#{default_server[:server]}/#{@database}",
#					default_server[:user], default_server[:password] ]
      connect() if connect
#      @db  =   DocumentDatabase.connect("remote:#{default_server[:server]}/#{@database}",
#					default_server[:user], default_server[:password] )
      ActiveOrient::Model.api = self 
      preallocate_classes  if preallocate

    end

    def db
      @db
    end

# Used for the connection on the server
    #

# Used to connect to the database

    def connect

      @db  =   DocumentDatabase.connect("remote:#{default_server[:server]}/#{@database}",
					default_server[:user], default_server[:password] )
      @classes =  get_database_classes
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
	this_class unless get_database_classes(requery: false).include?( this_class.ref_name ) rescue nil
      end.compact.uniq
      command= selected_classes.map do | database_class |
	## improper initialized ActiveOrient::Model-classes lack a ref_name class-variable
	next if database_class.ref_name.blank?  
	c = if database_class.superclass == ActiveOrient::Model || database_class.superclass.ref_name.blank?
	      puts "CREATE CLASS #{database_class.ref_name} "
	      OClassImpl.create @db, database_class.ref_name 
	    else
	      puts "CREATE CLASS #{database_class.ref_name} EXTENDS #{database_class.superclass.ref_name}"
	      OClassImpl.create @db, superClass: database_class.ref_name 
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
      @db.schema.drop_class classname(o_class)
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
    logger.progname = 'HavaApi#CreateRecord'
    attributes = yield if attributes.empty? && block_given?
    new_record = insert_document( o_class, attributes.to_orient )


  end
  alias create_document create_record

  def insert_document o_class, attributes
    d =  Document.create @db, classname(o_class), **attributes
    d.save
    ActiveOrient::Model.get_model_class(classname(o_class)).new attributes.merge( { "@rid" => d.rid,
										  "@version" => d.version,
										  "@type" => 'd',
										  "@class" => classname(o_class) } )



  end
  end
end

