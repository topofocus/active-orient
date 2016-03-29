module ModelClass

  ########### CLASS FUNCTIONS ######### SELF ####


  ######## INITIALIZE A RECORD FROM A CLASS ########

=begin
  orientdb_class is used to instantiate a ActiveOrient:Model:{class} by providing its name
  todo: implement object-inherence
=end

  def orientdb_class name:
    begin
      klass = Class.new(self)
      name = name.to_s.camelize
      if self.send :const_defined?, name
        retrieved_class = self.send :const_get, name
      else
        new_class = self.send :const_set, name, klass
        new_class.orientdb = orientdb
        new_class # return_value
      end
    rescue NameError => e
      logger.progname = "ModelClass#OrientDBClass"
      logger.error "ActiveOrient::Model::Class #{name} cannot be initialized."
      logger.error "class: #{klass.inspect}"
      logger.error "name: #{name.inspect}"
      logger.error "#{e.inspect}"
    end
  end

  ########## CREATE ############

# Create a new Record

  def create_record attributes: {}
    orientdb.create_record self, attributes: attributes
  end
  alias create_document create_record

=begin
  Only if the Class inherents from »E« instantiate a new Edge between two Vertices
  Parameter: unique: (true)
  In case of an existing Edge just update its Properties.
  The parameters »from« and »to« can take a list of model-records. Then subsequent edges are created.
   :call-seq:
    self.create_edge from:, to:, unique: false, attributes:{}
=end

  def create_edge **keyword_arguments
    new_edge = orientdb.create_edge self, **keyword_arguments
    [:from,:to].each{|y|
      keyword_arguments[y].is_a?(Array) ? keyword_arguments[y].each( &:reload! ) : keyword_arguments[y].reload!
    }
    new_edge
  end

=begin
  Creates a new Instance of the Class with the applied attributes if does not exists, otherwise update it. It returns the freshly instantiated Object
=end

  def update_or_create_records set: {}, where: {}, **args, &b
    orientdb.update_or_create_records self, set: set, where: where, **args, &b
  end
  alias update_or_create_documents update_or_create_records
  alias create_or_update_document update_or_create_records
  alias update_or_create update_or_create_records

  def create attributes = {}
    self.update_or_create_records set: attributes
  end

=begin
  Create a Property in the Schema of the Class
    :call-seq:  self.create_property(field (required), type:'string', linked_class: nil, index: nil) do
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

# Add a link property

  def create_link name, classname
    orientdb.create_property self, name, type: 'link', linked_class: classname
  end

# Add a linkset property

  def create_linkset name, classname
    orientdb.create_property self, name, type: 'linkset', linked_class: classname
  end

  ########## GET ###############

  def classname
    orientdb.classname self
  end

# get elements by rid

  def get rid
    orientdb.get_record rid
  end

# get all the elements of the class

  def all
    orientdb.get_records from: self
  end

# get the first element of the class

  def first where: {}
    orientdb.get_records(from: self, where: where, limit: 1).pop
  end

# get the last element of the class

  def last where: {}
    orientdb.get_records(from: self, where: where, order: {"@rid" => 'desc'}, limit: 1).pop
  end

# Get the properties of the class

  def get_properties
    object = orientdb.get_class_properties self
    {:properties => object['properties'], :indexes => object['indexes']}
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
      TestModel = r.open_class 'test_model'
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
    orientdb.get_records(from: self, **args){self}
  end
  alias get_documents get_records

=begin
  Performs a query on the Class and returns an Array of ActiveOrient:Model-Records.

  Example:
    Log = r.open_class 'Log'
    Log.where priority: 'high'
    --> submited database-request: query/hc_database/sql/select from Log where priority = 'high'/-1
    => [ #<ActiveOrient::Model::Log:0x0000000480f7d8 @metadata={ ... },  ...
=end

  def where attributes =  {}
    q = OrientSupport::OrientQuery.new from: self, where: attributes
    query_database q
  end

# Used to count of the elements in the class

  def count **args
    orientdb.count_records from: self, **args
  end

# Get the superclass of the class

  def superClass
    logger.progname = 'ActiveOrient::Model#Superclass'
    r = orientdb.get_classes('name', 'superClass').detect{|x|
      x["name"].downcase == new.class.to_s.downcase.split(':')[-1].to_s
    }['superClass']
    if r.empty?
      logger.info{"#{self} does not have any superclass. Probably it is a Document"}
    end
    return r
  end

=begin
  QueryDatabase sends the Query, direct to the database.
  The result is not nessessary an Object of self.
  However, if the query does not return an array of Active::Model-Objects, then the entries become self
=end

  def query_database query, set_from: true
    query.from self if set_from && query.is_a?(OrientSupport::OrientQuery) && query.from.nil?
    sql_cmd = -> (command) {{ type: "cmd", language: "sql", command: command }}
    orientdb.execute(self.to_s.split(':')[-1]) do
      [sql_cmd[query.to_s]]
    end
  end

  ########### DELETE ###############

# Delete a property from the class

  def delete_property field
    orientdb.delete_property self, field
  end

# Delete a record

  def delete_record *rid
    orientdb.delete_record rid
  end
  alias delete_document delete_record

# Delete a record from the class

  def delete_records where: {}
    orientdb.delete_records self, where: where
  end
  alias delete_documents delete_records

  ########### UPDATE #############

# Update records of a class

  def update_records set:, where:
    orientdb.update_records self, set: set, where: where
  end
  alias update_documents update_records

  ##################### EXPERIMENT #################

=begin
  Suppose that you created a graph where a vertex month is connected with
  the vertexes days by the edge TIMEOF.
  Suppose we want to find all the days in the first month and in the third month..

  Usually we can do in the following way.

  month = r.open_class "Month"
  firstmonth = month.first
  thirdmonth = month.all[2]
  days_firstmonth = firstmonth.out_TIMEOF.map{|x| x.in}
  days_thirdmonth = thirdmonth.out_TIMEOF.map{|x| x.in}

  However we can obtain the same result with the following command

  month = r.open_class "Month"
  month.add_edge_link name: "days", direction: "out", edge: "TIMEOF"
  firstmonth = month.first
  thirdmonth = month.all[2]
  days_firstmonth = firstmonth.days
  days_thirdmonth = thirdmonth.days

  To get their value you can do:
  thirdmonth.days.value
=end


  def add_edge_link name:, direction: "out", edge:
    logger.progname = 'RestEdge#AddEdgeLink'
    if direction == "out"
      dir = "in"
    elsif direction == "in"
      dir = "out"
    else
      logger.error{"Direction should be in or out."}
      return 0
    end
    define_method(name.to_sym) do
      return self["#{direction}_#{edge}"].map{|x| x["in"]}
    end
  end

end
