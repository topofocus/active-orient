module ModelClass
require 'stringio'
include OrientSupport::Support


  ########### CLASS FUNCTIONS ######### SELF ####


  ######## INITIALIZE A RECORD FROM A CLASS ########


=begin
NamingConvention provides a translation from database-names to class-names.

It can be overwritten to provide different conventions for different classes, eg. Vertexes or edges
and to introduce distinct naming-conventions in differrent namespaces

To overwrite use 
  class Model < ActiveOrient::Model[:: ...]
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

    ActiveOrient.database_classes[name].presence || ActiveOrient::Model
  rescue NoMethodError => e
    logger.error { "Error in orientdb_class: is ActiveOrient.database_classes initialized ? \n\n\n" }
    logger.error{ e.backtrace.map {|l| "  #{l}\n"}.join  }
    Kernel.exit
  end



=begin
requires the file specified in the model-dir

In fact, the model-files are loaded instead of required. 
Thus, even after recreation of a class (Class.delete_class, ORD.create_class classname) 
custom methods declared in the model files are present. 

Required modelfiles are gone, if the class is destroyed. 

The directory specified is expanded by the namespace. The directory specified as parameter is the base-dir.

Example:
  Namespace:  HC
  model_dir : 'lib/model'
  searched directory: 'lib/model/hc'

=end
def require_model_file  the_directory=nil
  logger.progname = 'ModelClass#RequireModelFile'
  the_directory = Pathname( the_directory.presence ||  ActiveOrient::Model.model_dir)   # the_directory is a Pathname
  if File.exists?( the_directory )
    model= self.to_s.underscore + ".rb"
    filename =   the_directory +  model
    if  File.exists?(filename )
      if load filename
	logger.info{ "#{filename} sucessfully loaded"  }
	self #return_value
      else
	logger.error{ "#{filename} load error" }
	nil #return_value
      end
    else
      logger.info{ "model-file not present: #{filename}" }
      nil #return_value
    end
  else
    logger.info{ "Directory #{ dir  } not present " }
    nil  #return_value
  end
rescue TypeError => e
     puts "TypeError:  #{e.message}" 
     puts "Working on #{self.to_s} -> #{self.superclass}"
     puts "Class_hierarchy: #{orientdb.class_hierarchy.inspect}."
     print e.backtrace.join("\n") 
     raise
  #
end

  ########## CREATE ############

=begin
Universal method to create a new record. 
It's overloaded to create specific kinds, eg. edges 

Example:
  ORD.create_class :test
  Test.create string_attribute: 'a string', symbol_attribute: :a_symbol, array_attribute: [34,45,67]
  Test.create link_attribute: Test.create( :a_new_attribute => 'new' )

=end
  def create **attributes
    attributes.merge :created_at => DateTime.new
    db.create_record self, attributes: attributes 
  end

=begin 
Creates or updates a record.
Parameter: 
- set: A hash of attributes to insert or update unconditionally
- where: A string or hash as condition which should return just one record.

The where-part should be covered with an unique-index.

returns the affected record
=end
  def upsert set:, where: 
			specify_return_value =  "return after @rid"
#			set.merge! where if where.is_a?( Hash ) # copy where attributes to set 
			command = "Update #{ref_name} set #{generate_sql_list( set ){','}} upsert #{specify_return_value}  #{compose_where where}"
      query_database(command, set_from: false){| record |  record.reload! } &.first
    #db.upsert self, set: set, where: where, &b
  end
=begin
Create a new Instance of the Class with the applied attributes if does not exists, 
otherwise update it. It returns the freshly instantiated Objects
=end

  def update_or_create_records set: {}, where: {}, **args, &b
    db.update_or_create_records self, set: set, where: where, **args, &b
  end

  alias update_or_create_documents update_or_create_records

=begin
Sets a value to certain attributes, overwrites existing entries, creates new attributes if nessesary

  IB::Account.update_all connected: false
  IB::Account.update_all where: "account containsText 'F'", set:{ connected: false }

**note: By calling UpdateAll, all records of the Class previously stored in the rid-cache are removed from the cache. Thus autoload gets the updated records.
=end

  def update_all where: {} , set: {},  **arg
    if where.empty?
      set.merge! arg
    end
    db.update_records  self, set: set, where: where

  end
  #
# removes a property from the collection (where given) or the entire class 
  def remove attribute, where:{}
    db.update_records self, remove: attribute, where: where
  end

=begin
Create a Property in the Schema of the Class

Examples:

      create_property  :customer_id, type: integer, index: :unique
      create_property  :name, type: :string, index: :not_unique
      create_property  :in,  type: :link, linked_class: :V    (used by edges)

:call-seq:  create_property(field (required), 
			    type: 'a_string',
			    linked_class: nil, index: nil) do
    	index
    end
=end

  def create_property field, **keyword_arguments, &b
    orientdb.create_property self, field, **keyword_arguments, &b
  end

# Create more Properties in the Schema of the Class

  def create_properties argument_hash, &b
    orientdb.create_properties self, argument_hash, &b
  end


# Add an Index
  def create_index name, **attributes
    orientdb.create_index self, name: name, **attributes
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
    db.get_records from: self
  end

# get the first element of the class

  def first where: {}
    db.get_records(from: self, where: where, limit: 1).pop
  end

# get the last element of the class

  def last where: {}
    db.get_records(from: self, where: where, order: {"@rid" => 'desc'}, limit: 1).pop
  end
# Used to count of the elements in the class

  def count **args
    orientdb.count from: self, **args
  end

# Get the properties of the class

  def get_properties
    object = orientdb.get_class_properties self
    HashWithIndifferentAccess.new :properties => object['properties'], :indexes => object['indexes']
  end
  alias get_class_properties get_properties

# Print the properties of the class

  def print_class_properties
    orientdb.print_class_properties self
  end

=begin
»GetRecords« uses the REST-Interface to query the database. The alternative »QueryDatabase« submits 
the query via Batch. 

Both methods rely on OrientSupport::OrientQuery and its capacity to support complex query-builds.
The method requires a hash of arguments. The following keys are supported:

*projection:*

SQL-Queries use »select« to specify a projection (ie. `select sum(a), b+5 as z from class where ...`)

In ruby »select« is a method of enumeration. To specify anything etween »select« and »from« in the query-string
we use  »projection«, which acceps different arguments

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


  def custom_where search_string
    q = OrientSupport::OrientQuery.new from: self, where: search_string
    #puts q.compose
    query_database q
  end
=begin
Performs a query on the Class and returns an Array of ActiveOrient:Model-Records.

Example:
    Log.where priority: 'high'
    --> submited database-request: query/hc_database/sql/select from Log where priority = 'high'/-1
    => [ #<Log:0x0000000480f7d8 @metadata={ ... },  ...
  
Multible arguments are joined via "and" eg
    Aktie.where symbol: 'TSL, exchange: 'ASX'
    ---> select  from aktie where symbol = 'TLS' and exchange = 'ASX'


Where performs a »match-Query« that returns only links to the queries records.
These are autoloaded (and reused from the cache). If changed database-records should  be obtained,
custom_query should be used. It performs a "select form class where ... " query which returns  records
instead of links.

    Property.custom_where( "'Hamburg' in exchanges.label")

=end

  def where *attributes 
    query= OrientSupport::OrientQuery.new kind: :match, start:{ class: self.classname }
    query.match_statements[0].where =  attributes unless attributes.empty?
    result = query_database(query, set_from: false){| record | record[ self.classname.pluralize ] }
#    result.self.classname.pluralize
#    q= if block_given?
#      "select from #{self.ref_name} #{ orientdb.compose_where attributes, &b} "
#       else
#      OrientSupport::OrientQuery.new( from: self, where: attributes) 
#       end
#    query_database q
  end
=begin
Performs a Match-Query

The Query starts at the given ActiveOrient::Model-Class. The where-cause narrows the sample to certain 
records. In the simplest version this can be returned:
  
  Industry.match where:{ name: "Communications" }
  => #<ActiveOrient::Model::Query:0x00000004309608 @metadata={"type"=>"d", "class"=>nil, "version"=>0, "fieldTypes"=>"Industries=x"}, @attributes={"Industries"=>"#21:1", (...)}>

The attributes are the return-Values of the Match-Query. Unless otherwise noted, the pluralized Model-Classname is used as attribute in the result-set.

  I.match( where: { name: 'Communications' }).first.Industries

is the same then
  Industry.where name: "Communications" 

  
The Match-Query uses this result-set as start for subsequent queries on connected records.
These connections are defined in the Block

  var = Industry.match do | query |
    query.connect :in, count: 2, as: 'Subcategories'
    puts query.to_s  # print the query send to the database
    query            # important: block has to return the query 
  end
  => MATCH {class: Industry, as: Industries} <-- {} <-- { as: Subcategories }  RETURN Industries, Subcategories

The result-set has two attributes: Industries and Subcategories, pointing to the filtered datasets.

By using subsequent »connect« and »statement« method-calls even complex Match-Queries can be clearly constructed. 

=end

  def match where: {}
    query= OrientSupport::OrientQuery.new kind: :match, start:{ class: self.classname }
    query.match_statements[0].where =  where unless where.empty?
    if block_given?
      query_database yield(query), set_from: false
    else
      logger.progname = 'ActiveOrient::Model#Match'
      logger.error{ "Query-Details have to be specified in a Block" }
    end

  end


=begin
QueryDatabase sends the Query directly to the database.

The result is not nessessary an Object of the Class.

The result can be modified further by passing a block.
This is helpful, if a match-statement is used and the records should be autoloaded:

  result = query_database(query, set_from: false){| record | record[ self.classname.pluralize ] }

This autoloads (fetches from the cache/ or database) the attribute self.classname.pluralize  (taken from method: where )
  

query_database is used on model-level and submits
  select (...) from class

#query performs queries on the instance-level and submits
  select (...) from #{a}:{b}
  
=end

  def query_database query, set_from: true
    query.from self if set_from && query.is_a?(OrientSupport::OrientQuery) && query.from.nil?
    sql_cmd = -> (command) {{ type: "cmd", language: "sql", command: command }}
    result = db.execute do
      sql_cmd[query.to_s]
    end
    if block_given?
      result.is_a?(Array)? result.map{|x| yield x } : yield(result)
    else
      result
    end
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

  def delete_records where: {}
    orientdb.delete_records self, where: where
  end
  alias delete_documents delete_records



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

  def alter_property property:, attribute: "DEFAULT", alteration:  # :nodoc:
    orientdb.alter_property self, property: property, attribute: attribute, alteration: alteration
  end


  
end
