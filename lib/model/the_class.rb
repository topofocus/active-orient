module ModelClass
require 'stringio'
include OrientSupport::Support


  ########### CLASS FUNCTIONS ######### SELF ####


  ######## INITIALIZE A RECORD FROM A CLASS ########


=begin
NamingConvention provides a translation from database-names to class-names.

It can be overwritten to provide different conventions for different classes, eg. Vertexes or edges
and to introduce distinct naming-conventions in different namespaces

To overwrite use 
  class Model # < ActiveOrient::Model[:: ...]
    def self.naming_convention
    ( conversion code )
    end
 end
=end
  def naming_convention name=nil  
    nc =  name.present?? name.to_s : ref_name
     if namespace_prefix.present?
    	 nc.split(namespace_prefix).last.camelize
     else
       nc.camelize
     end
	rescue
		nil
  end


=begin
Set the namespace_prefix for database-classes.

If a namespace is set by
  ActiveOrient::Init.define_namespace { ModuleName }
ActiveOrient translates this to 
  ModuleName::CamelizedClassName
The database-class becomes
  modulename_class_name

If the namespace is set to a class (Object, ActiveOrient::Model ) namespace_prefix returns an empty string.

Override to change its behavior
=end
  def namespace_prefix 
    namespace.is_a?(Class )? '' : namespace.to_s.downcase+'_' 
  end
=begin
  orientdb_class is used to refer a ActiveOrient:Model-Object providing its name

  Parameter: name: string or symbol
=end

  def orientdb_class name:, superclass: nil  # :nodoc:    # public method: autoload_class

    ActiveOrient.database_classes[name.to_s].presence || ActiveOrient::Model
  rescue NoMethodError => e
    logger.error { "Error in orientdb_class: is ActiveOrient.database_classes initialized ? \n\n\n" }
    logger.error{ e.backtrace.map {|l| "  #{l}\n"}.join  }
    Kernel.exit
  end


=begin
	setter method to initialise a dummy ActiveOrient::Model class to enable multi-level 
	access to links and linklists
=end

def link_list *property
	property.each do |p|
		
		the_dummy_class = orientdb.allocate_class_in_ruby("dummy_"+p.to_s)
		the_dummy_class.ref_name =  ref_name + "." +  p.to_s
		singleton_class.send :define_method, p do
			the_dummy_class
		end
	end

end

=begin
requires the file specified in the model-dir

In fact, the model-files are loaded instead of required. 
Thus, even after recreation of a class (Class.delete_class, ORD.create_class classname) 
custom methods declared in the model files are present. 

If a class is destroyed (i.e. the database class is deleted), the ruby-class and its methods vanish, too.

The directory specified is expanded by the namespace. The  parameter itself is the base-dir.

Example:
  Namespace:  HC
  model_dir : 'lib/model'
  searched directory: 'lib/model/hc'


ActiveOrient::Model.modeldir is aimed to be set to the application dir. It may be a String, Pathname or
an array of strings or pathnames. 

The parameter `dir` is used internally and by gems to ensure that basic methods are loaded first. 


=end
def require_model_file  dir = nil
	logger.progname = 'ModelClass#RequireModelFile'
	# model-dir can either be a string or an array of string or pathnames
	default =  [ActiveOrient::Model.model_dir].flatten
	# access the default dir's first
	the_directories = case dir
										when String, Pathname
										  default.present? ? 	[dir] + default : [dir]
										when Array
											default.present? ? dir + default  : dir
										else
											default.present? ? default : []
										end.uniq.compact
	the_directories.uniq.map do |raw_directory|
		the_directory = Pathname( raw_directory )
		if File.exists?( the_directory )
			model= self.to_s.underscore + ".rb"
			filename =   the_directory +  model
			if  File.exists?(filename )
				if load filename
					logger.debug{ "#{filename} sucessfully loaded"  }
					self #return_value
				else
					logger.error{ "#{filename} load error" }
					nil #return_value
				end
			else
				logger.debug{ "model-file not present: #{filename}  --> skipping" }
				nil #return_value
			end
		else
			logger.error{ "Directory #{ the_directory  } not present " }
			nil  #return_value
		end
	end.compact.present?  # return true only if at least one model-file is present

	rescue TypeError => e
		puts "THE CLASS#require_model_file -> TypeError:  #{e.message}" 
		puts "Working on #{self.to_s} -> #{self.superclass}"
		puts "Class_hierarchy: #{orientdb.class_hierarchy.inspect}."
		print e.backtrace.join("\n") 
		raise
		#
	end


  # creates an inherent class
	def create_class *c
		orientdb.create_class( *c ){ self }
	end

  ########## CREATE ############

=begin
Universal method to create a new record. 
It's overloaded to create specific kinds, eg. edge and vertex  and is called only for abstract classes

Example:
  V.create_class :test
  Test.create string_attribute: 'a string', symbol_attribute: :a_symbol, array_attribute: [34,45,67]
  Test.create link_attribute: Test.create( :a_new_attribute => 'new' )

=end
  def create **attributes
    attributes.merge :created_at => DateTime.new
		result = db.create_record self, attributes: attributes
		if result.nil
			logger.error('Model::Class'){ "Table #{refname}:  create failed:  #{attributes.inspect}" }
		elsif block_given?
			yield result
		else
			result  # return value
		end
	end


	# returns a OrientSupport::OrientQuery 
	def query **args
		OrientSupport::OrientQuery.new( **( {from: self}.merge args))
	end

=begin 
Creates or updates  records.
Parameter: 
- set: A hash of attributes to insert or update unconditionally
- where: A string or hash as condition which should return just one record.

The where-part should be covered with an unique-index.


returns the affected record, if the where-condition is set properly.
Otherwise upsert acts as »update« and returns all updated records (as array).
=end
  def upsert set: nil, where: , **args
		set = where if set.nil?
		query( **args.merge( kind: :upsert, set: set, where: where )).execute(reduce: true){|y| y[:$current].reload!}
  end
=begin
Sets a value to certain attributes, overwrites existing entries, creates new attributes if necessary

returns the count of affected records

  IB::Account.update connected: false
  IB::Account.update where: "account containsText 'F'", set:{ connected: false }
#	or
  IB::Account.update  connected: false, where: "account containsText 'F'"
=end

  def update! where: nil , set: {},  **arg
		query( kind: :update!, set: set.merge(arg), where: where).execute(reduce: true){|y| y[:count]}
  end

	alias update_all update!


# same as update!, but returns a list of  updated records
	def update where:  , set: {},  **arg
		# In OrientDB V.3 the database only returns the affected rid's 
		# We have to update the contents manually, this is done in the execute-block
		query( kind: :update, set: set.merge(arg), where: where).execute{|y| y[:$current].reload!}
	end

=begin
Create a Property in the Schema of the Class and optionally create an automatic index

Examples:

      create_property  :customer_id, type: :integer, index: :unique
      create_property(  :name, type: :string ) {  :unique  }
      create_property(  :name, type: :string ) { name: 'some_index', on: :automatic, type: :unique  }
      create_property  :in,  type: :link, linked_class: V    (used by edges)

:call-seq:  create_property(field (required), 
			    type: :a_supported_type',
			    linked_class: nil

supported types: 
	:bool         :double       :datetime  = :date    :float        :decimal      
	:embedded_list = :list      :embedded_map = :map        :embedded_set = :set          
	:int          :integer      :link_list    :link_map     :link_set     

If  `:list`, `:map`, `:set`, `:link`, `:link_list`, `:link_map` or `:link_set` is specified
a `linked_class:` parameter can be specified. Argument is the OrientDB-Class-Constant
=end
  def create_property field, type: :integer, index: nil,  **args
		arguments =  args.values.map do |y| 
			if y.is_a?(Class)  && ActiveOrient.database_classes.values.include?(y) 
				y.ref_name 
			elsif  ActiveOrient.database_classes.keys.include?(y.to_s) 
				y 
			else
				puts ActiveOrient.database_classes.inspect
				puts "YY : #{y.to_s} #{y.class}"
				raise ArgumentError , "database class #{y.to_s} not allocated"
			end
		end.compact.join(',')

		supported_types = {
			:bool          => "BOOLEAN",
			:double        => "BYTE",
			:datetime      => "DATE",
			:date			     => "DATE",
			:float         => "FLOAT",
			:decimal       => "DECIMAL",
			:embedded_list => "EMBEDDEDLIST",
			:list          => "EMBEDDEDLIST",
			:embedded_map  => "EMBEDDEDMAP",
			:map           => "EMBEDDEDMAP",
			:embedded_set  => "EMBEDDEDSET",
			:set           => "EMBEDDEDSET",
			:string        => "STRING",
			:int           => "INTEGER",
			:integer       => "INTEGER",
			:link          => "LINK",
			:link_list     => "LINKLIST",
			:link_map      => "LINKMAP",
			:link_set      => "LINKSET",
		}

		## if the »type« argument is a string, it is used unchanged
		type =  supported_types[type] if type.is_a?(Symbol)

		raise ArgumentError , "unsupported type" if type.nil?
	s= " CREATE PROPERTY #{ref_name}.#{field} #{type} #{arguments}" 
	puts s
	db.execute {  s }

	i =  block_given? ? yield : index
	## supported format of block:  index: { name: 'something' , on: :automatic, type: :unique } 
	## or                                 { name: 'something' , on: :automatic, type: :unique }  # 
	## or                                 {                                some_name: :unique }  # manual index
	## or                                 {                                           :unique }  # automatic index
	if i.is_a? Hash  
		att=  i.key( :index ) ?   i.values.first : i
		name, on, type = if  att.size == 1  && att[:type].nil? 
											 [att.keys.first,  field,  att.values.first ]
										 else  
											 [ att[:name] || field , att[:on] || field , att[:type] || :unique ]
										 end
		create_index( name , on: on, type: type)
	elsif i.is_a?(Symbol)  || i.is_a?(String)
		create_index field, type: i
	end

	# orientdb.create_property self, field, **keyword_arguments, &b
	end

# Create more Properties in the Schema of the Class

  def create_properties argument_hash, &b
    orientdb.create_properties self, argument_hash, &b
  end


# Add an Index
	#
	# Parameters:  
	#							name (string / symbol), 
	#             [ on: :automatic / single Column, Array of Columns,
	#             [ type: :unique, :nonunique, :dictionary,:fulltext, {other supported index-types} ]]
	#
	# Default:
	#							on: :automatic
	#							type: :unique
	#
	# Example
	#   
	#   ORD.create_vertex_class :pagination
  #  	Pagination.create_property :col1 , type: :string
	#		Pagination.create_property :col2, type: :integer
	#		Pagination.create_property :col3, type: :string
	#		Pagination.create_property :col4, type: :integer
	#		Pagination.create_index :composite,  :on => [:col1, :col2, :col3], type: 'dictionary'

  def create_index name, **attributes
    orientdb.create_index self, name: name, **attributes
  end

# list all Indexes
	def indexes
		properties[:indexes]
	end


	def migrate_property property, to: , linked_class: nil, via: 'tzr983'
		if linked_class.nil?
			create_property  via, type: to
		else
			create_property  via, type: to, linked_class: linked_class
		end
#			my_count = query.kind(:update!).set( "#{via} = #{property} ").execute(reduce: true){|c| c[:count]}
#			logger.info{" migrate property: #{count} records prosessed"}
		  all.each{ |r| r.update set:{ via => r[property.to_sym] }}
			nullify =  query.kind(:update!).set( property: nil ).execute(reduce: true){|c| c[:count]}
#		  raise "migrate property: count of erased items( #{nullify} differs from total count (#{my_count}) " if nullify != my_count
			db.execute{" alter property #{ref_name}.#{via} name '#{property}' "}
			logger.info{ "successfully migrated #{property} to #{:to} " }








	end
  ########## GET ###############

  def classname  # :nodoc: #
     ref_name
  end

# get elements by rid

  def get rid
    if @excluded.blank?
      db.get_record(rid)
    else
      db.execute{ "select expand( @this.exclude( #{@excluded.map(&:to_or).join(",")})) from #{rid} "} 
    end
  end

# get all the elements of the class

  def all
		query.execute
  end

# get the first element of the class

  def first **args
    query( **( { order: "@rid" , limit: 1 }.merge args)).execute(reduce: true)
	end
   # db.get_records(from: self, where: where, limit: 1).pop
  #end

# get the last element of the class
  def last **args
    query( **( { order: {"@rid" => 'desc'} , limit: 1 }.merge args)).execute(reduce: true)
	end

# Used to count of the elements in the class
# 
	# Examples
	#    TestClass.count where: 'last_access is NULL'  # only records where 'last_access' is not set
	#    TestClass.count                               # all records
  def count **args
		query( **( { projection:  'COUNT(*)' }.merge args )).execute(reduce: true){|x|  x[:"COUNT(*)"]}
  end

# Get the properties of the class

  def properties
    object = orientdb.get_class_properties self
    {:properties => object['properties'], :indexes => object['indexes']}
  end
  alias get_class_properties properties

# Print the properties of the class

  def print_properties
    orientdb.print_class_properties self
  end

=begin
»GetRecords« uses the REST-Interface to query the database. The alternative »QueryDatabase« submits 
the query via Execute. 

Both methods rely on OrientSupport::OrientQuery and its capacity to support complex query-builds.
The method requires a hash of arguments. The following keys are supported:

*projection:*

SQL-Queries use »select« to specify a projection (ie. `select sum(a), b+5 as z from class where ...`)

In ruby »select« is a method of enumeration. To specify what to »select« from  in the query-string
we use  »projection«, which accepts different arguments

    projection: a_string --> inserts the sting as it appears
    projection: an OrientSupport::OrientQuery-Object --> performs a sub-query and uses the result for further querying though the given parameters.
    projection: [a, b, c] --> "a, b, c" (inserts a comma-separated list)
    projection: {a: b, "sum(x)" => f} --> "a as b, sum(x) as f" (renames properties and uses functions)

*distinct:*

Constructs a query like »select distinct(property) [as property] from ...«

  distinct: :property -->  the result is mapped to the property »distinct«.
  distinct: [:property] --> the result replaces the property
  distinct: {property: :some_name} -->  the result is mapped to ModelInstance.some_name

*order:*
 
 Sorts the result-set. If new properties were introduced via select:, distinct: etc. Sorting takes place on these properties

  order: :property {property: asc, property: desc}[property, property, ..  ](orderdirection is 'asc')


Further supported Parameter:

  group_by
  skip
  limit
  unwind

  see orientdb- documentation (https://orientdb.com/docs/last/SQL-Query.html)

*query:*

Instead of providing the parameter to »get_records«, a OrientSupport::OrientQuery can build and 
tested prior to the method-call. The OrientQuery-Object is then provided with the query-parameter. I.e.

  q = OrientSupport::OrientQuery.new
  ORD.create_class :test_model
     q.from TestModel
     q.where {name: 'Thomas'}
     count = TestModel.count query: q
     q.limit 10
     0.step(count,10) do |x|
        q.skip = x
        puts TestModel.get_documents(query: q).map{|x| x.adress }.join('\t')
     end
    prints a Table with 10 columns.
=end

  def get_records **args
    db.get_records(from: self, **args){self}
  end
  alias get_documents get_records


=begin
Performs a query on the Class and returns an Array of ActiveOrient:Model-Records.

Fall-back method, is overloaded by Vertex.where 

Is aliased by »custom_where»

Example:
    Log.where priority: 'high'
    --> submitted database-request: query/hc_database/sql/select from Log where priority = 'high'/-1
    => [ #<Log:0x0000000480f7d8 @metadata={ ... },  ...
  
Multiple arguments are joined via "and" eg:
    Aktie.where symbol: 'TSL, exchange: 'ASX'
    ---> select  from aktie where symbol = 'TLS' and exchange = 'ASX'

=end

  def where *attributes 
    q= OrientSupport::OrientQuery.new  where: attributes 
    query_database( q)
  end

	alias custom_where where
=begin
QueryDatabase sends the Query directly to the database.

The query returns a hash if a result set is expected
  select  {something} as {result} (...) 
leads to
  [ { :{result}  =>  {result of query} } ]

It can be modified further by passing a block, ie.

  	q =  OrientSupport::OrientQuery.new( from: :base )
		                               .projection( 'first_list[5].second_list[9] as second_list' )
		                               .where( label: 9 )

    q.to_s  => 'select first_list[5].second_list[9] as second_list from base where label = 9 '

		second_list = Base.query_database( q ){|x|  x[:second_list]}.first


The query returns (a list of) documents of type ActiveOrient::Model if a document is queried i.e.

	q =  OrientSupport::OrientQuery.new  from: :base
	q.projection  'expand( first_list[5].second_list[9])'  #note: no 'as' statement
	result2 = Base.query_database( q ).first
	=> #<SecondList:0x000000000284e840 @metadata={}, @d=nil, @attributes={:zobel=>9, "@class"=>"second_list"}>
  




query_database is used on model-level and submits
  select (...) from class

#query performs queries on the instance-level and submits
  select (...) from #{a}:{b}
  
=end

  def query_database query, set_from: true
    # note: the parameter is not used anymore
		query.from self if query.is_a?(OrientSupport::OrientQuery) && query.from.nil?
    result = db.execute{  query.to_s  }
		result = if block_given?
							 result.is_a?(Array) ? result.map{|x| yield(x) } : yield(result)
						 else
							 result
						 end
    if result.is_a? Array  
      OrientSupport::Array.new work_on: self, work_with: result
    else
      result
    end  # return value
  end

  ########### DELETE ###############

# Delete a property from the class

  def delete_property field
    orientdb.delete_property self, field
  end

# Delete  record(s) specified by their rid's

  def delete_record *rid
    db.delete_record rid
  end
  alias delete_document delete_record

# Query the database and delete the records of the resultset
# 
# Returns the count of datasets effected
  def delete_records where: {} , **args
		if args[:all] == true 
			where = {}
		else
			where.merge!(args) if where.is_a?(Hash)
			return 0 if where.empty?
		end
    orientdb.delete_records( self, where: where   ).count
	end
  alias delete delete_records



  ##################### EXPERIMENT #################

=begin
Suppose that you created a graph where vertexes month is connected with
the vertexes day by the edge TIMEOF.
Suppose we want to find all the days in the first month and in the third month..

Usually we can do in the following way.

  ORD.create_class :month
  (.. put some records into Month ... )
  firstmonth = Month.first
  thirdmonth = Month.all[2]
  days_firstmonth = firstmonth.out_TIMEOF.map{|x| x.in}
  days_thirdmonth = thirdmonth.out_TIMEOF.map{|x| x.in}

However we can obtain the same result with the following command

  Month.add_edge_link name: "days", direction: "out", edge: TIME_OF
  firstmonth = month.first
  thirdmonth = month.all[2]
  days_firstmonth = firstmonth.days
  days_thirdmonth = thirdmonth.days

To get their value you can do:
  thirdmonth.days.value
=end


  def add_edge_link name:, direction: :out, edge:
    dir =  direction.to_s == "out" ? :out : :in
    define_method(name.to_sym) do
      return self["#{dir}_#{edge.classname}"].map{|x| x["in"]}
    end
  end

=begin
 See http://orientdb.com/docs/2.1/SQL-Alter-Property.html
=end

  def alter_property property, attribute: "DEFAULT", alteration:  # :nodoc:
    orientdb.alter_property self, property: property, attribute: attribute, alteration: alteration
  end


  
end
