module ModelClass

  ########### CLASS FUNCTIONS ######### SELF ####


  ######## INITIALIZE A RECORD FROM A CLASS ########


=begin
NamingConvention provides a translation from database-names to class-names.

Should provide 
   to_s.capitalize_first_letter
as minimum.
Can be overwritten to provide different conventions for different classes, eg. Vertexes or edges.

To overwrite use 
  class Model < ActiveOrient::Model[:: ...]
    def self.naming_convention
    ( conversion code )
    end
 end
=end
  def naming_convention name=nil  # :nodoc:
    name.present? ? name.to_s.camelize : ref_name.camelize
  end

=begin
  orientdb_class is used to create or refer a ActiveOrient:Model:{class} by providing its name

  Parameter: name: string or symbol
  Parameter: superclass: If class, then this is used unmodified
			 If string or symbol, its used to reference an existing class
			 if :find_ME, its derived from the classes-hash
  Attention: If a class is created by orientdb_class, its only allocated in ruby-space.
	     The class is thus not present in the classes-array, which reflects the database-classes.
	     If a class depending on a superclass is to be created, the superclass is derived from
	     the classes-array. In such a case, the allocation only works, if the class itself is
	     used as parameter "superclass" 
	     i.e.
	     ActiveOrient::Model.orientdb_class name: 'hurra'
	     AvtiveOrient::Model.orientdb_class name: 'hip_hip' , superclass: Hurra
=end

  def orientdb_class name:, superclass: nil   # :nodoc:    # public method: autoload_class
    logger.progname = "ModelClass#OrientDBClass"
    # @s-class is a cash for actual String -> Class relations
    self.allocated_classes = HashWithIndifferentAccess.new( V: V, E: E) unless allocated_classes.present?

    #update_my_array = ->(s) { self.allocated_classes[s.ref_name] = s unless allocated_classes[s.ref_name].present? }
    update_my_array = ->(s) do
      if  allocated_classes[s.ref_name].present? 
#	puts "found ref_name: #{allocated_classes[s.ref_name]}"
      else
      self.allocated_classes[s.ref_name] = s 
      end

    end
    get_class =  ->(n) { allocated_classes[n] }


    ref_name =  name.to_s
    klass = if superclass.present?   # superclass is parameter, use if class, otherwise transfer to class
	      s= if superclass.is_a? Class
		   namespace.send( :const_get, superclass.to_s )
		 else
		   superclass = orientdb.get_db_superclass( ref_name ) if superclass == :find_ME
		   if superclass.present?
		     namespace.send( :const_get, get_class[superclass].to_s )
		   else
		     self
		   end
		 end
	      Class.new(s)
	    else
	      Class.new(self)
	    end
    # namespace is defined in config/boot
    name = klass.naming_convention ref_name #
    if namespace.send :const_defined?, name
      retrieved_class = namespace.send :const_get, name
    else

      new_class = namespace.send :const_set, name, klass
      new_class.ref_name =  ref_name
      update_my_array[new_class]
#      logger.debug{"created:: Class #{new_class} < #{new_class.superclass} "}
#      logger.debug{"database-table:: #{ref_name} "}
      new_class # return_value
    end
  rescue NameError => e
      logger.error "ModelClass #{name.inspect} cannot be initialized."
      logger.error e.message
      logger.error e.backtrace.map {|l| "  #{l}\n"}.join  
      nil  # return_value
    #end
  end
=begin
Retrieves the preallocated class derived from ActiveOrient::Model

Only classes noted in the @classes-Array of orientdb are fetched.
=end
  def get_model_class name
    if orientdb.database_classes.include?(name)
      orientdb_class name: name, superclass: :find_ME
    else
      nil
    end
  end



=begin
requires the file specified in the model-dir

In fact, the model-files are loaded instead of required. After recreation of a class (Class.delete_class, 
ORD.create_class classname) custom methods declared in the model files are present. Required modelfiles are
gone, if the class is destroyed, but the interpreter thinks, they have already been required. Rebuilding the 
class does not reestablish the connection to the required model file.

Actual only a flat directory is supported. However -the Parameter model has the format: [ superclass, class ]. Its possible to extend the method adress a model-tree.
=end
def require_model_file  dir=nil
  logger.progname = 'ModelClass#RequireModelFile'
  dir = dir.presence ||  ActiveOrient::Model.model_dir 
  if File.exists?( dir )
    model= model.flatten.last if model.is_a?( Array )
    filename =   dir + "/" + self.to_s.underscore + '.rb'
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
It's obverloaded to create specific kinds, eg. edges 

Example:
  ORD.create_class :test
  Test.create string_attribute: 'a string', symbol_attribute: :a_symbol, array_attribute: [34,45,67]
  Test.create link_attribute: Test.create( :a_new_attribute => 'new' )

=end
  def create **attributes
    attributes.merge :created_at => Time.new
    db.create_record self, attributes: attributes 
  end

=begin 
Creates or updates a record.
Parameter: 
 set: A hash of attributes to insert or update unconditionally
 where: A string or hash as condition which should return just one record.

The where-part should be covered with an unique-index.
If :where is omitted, #Upsert becomes #Create, attributes are taken from :set.

returns the affected record
=end
  def upsert set: {}, where: {}, &b
    db.upsert self, set: set, where: where, &b
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
    :call-seq:  Model.create_property(field (required), type:'string', linked_class: nil, index: nil) do
    	index
    end

    Examples:

      create_property  :customer_id, type: integer, index: :unique
      create_property  :name, type: :string, index: :not_unique
      create_property  :in,  type: :link, linked_class: :V    (used by edges)
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
    db.get_record rid
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
  Parameter projection:
  »select« is a method of enumeration, we use  »projection:« to specify anything between »select« and »from« in the query-string.
    projection: a_string --> inserts the sting as it appearsb
    an OrientSupport::OrientQuery-Object --> performs a sub-query and uses the result for further querying though the given parameters.
    [a, b, c] --> "a, b, c" (inserts a comma-separated list)
    {a: b, "sum(x)" => f} --> "a as b, sum(x) as f" (renames properties and uses functions)

  Parameter distinct:
  Performs a Query like » select distinct(property) [as property] from ...«
    distinct: :property -->  the result is mapped to the property »distinct«.
    [:property] --> the result replaces the property
	  {property: :some_name} -->  the result is mapped to ModelInstance.some_name

  Parameter Order
  Sorts the result-set. If new properties are introduced via select:, distinct: etc. Sorting takes place on these properties
    order: :property {property: asc, property: desc}[property, property, ..  ](orderdirection is 'asc')

  Further supported Parameter:
    group_by
    skip
    limit
    unwind

  see orientdb- documentation (https://orientdb.com/docs/last/SQL-Query.html)

  Parameter query:
    Instead of providing the parameter, the OrientSupport::OrientQuery can build and tested before the method-call. The OrientQuery-Object can be provided with the query-parameter. I.e.
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

  Example:
    Log.where priority: 'high'
    --> submited database-request: query/hc_database/sql/select from Log where priority = 'high'/-1
    => [ #<Log:0x0000000480f7d8 @metadata={ ... },  ...
=end

  def custom_where search_string
    q = OrientSupport::OrientQuery.new from: self, where: search_string
    #puts q.compose
    query_database q
  end
  def where **attributes 
    ##puts "ATTRIBUTES: "+attributes.inspect
    q = OrientSupport::OrientQuery.new from: self, where: attributes
    query_database q
  end
=begin
Performs a Match-Query

The Query starts at the given ActiveOrient::Model-Class. The where-cause narrows the sample to certain 
records. In the simplest version this can be returnd:
  
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
  QueryDatabase sends the Query, direct to the database.
  The result is not nessessary an Object of self.
  However, if the query does not return an array of Active::Model-Objects, then the entries become self
=end

  def query_database query, set_from: true
    query.from self if set_from && query.is_a?(OrientSupport::OrientQuery) && query.from.nil?
    sql_cmd = -> (command) {{ type: "cmd", language: "sql", command: command }}
    db.execute do
      sql_cmd[query.to_s]
    end
  end

  ########### DELETE ###############

# Delete a property from the class

  def delete_property field
    orientdb.delete_property self, field
  end

# Delete a record

  def delete_record *rid
    db.delete_record rid
  end
  alias delete_document delete_record

# Delete a record from the class

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

  ORD.create_class "Month"
  (.. put some records into Month ... )
  firstmonth = Month.first
  thirdmonth = month.all[2]
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

  def alter_property property:, attribute: "DEFAULT", alteration:
    orientdb.alter_property self, property: property, attribute: attribute, alteration: alteration
  end


  
end
