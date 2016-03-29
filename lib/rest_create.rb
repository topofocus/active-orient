module RestCreate

  ######### DATABASE ##########

=begin
  Creates a database with the given name and switches to this database as working-database. Types are either 'plocal' or 'memory'
  Returns the name of the working-database
=end

  def create_database type: 'plocal', database: @database
    logger.progname = 'RestCreate#CreateDatabase'
  	old_d = @database
  	@classes = []
  	@database = database
  	begin
      response = @res[database_uri{type}].post ""
      if response.code == 200
        logger.info{"Database #{@database} successfully created and stored as working database"}
      else
        @database = old_d
        logger.error{"Database #{name} was NOT created. Working Database is still #{@database}"}
      end
    rescue RestClient::InternalServerError => e
      @database = old_d
      logger.error{"Database #{name} was NOT created. Working Database is still #{@database}"}
    end
    @database
  end

  ######### CLASS ##########

=begin
  Creates classes and class-hierachies in OrientDB and in Ruby.
  Takes an Array or a Hash as argument and returns an Array of
  successfull allocated Ruby-Classes
  If the argument is an array, Basic-Classes are build.
  Otherwise key/value pairs are assumend to follow this terminology
   {SuperClass => [class, class, ...], SuperClass => [] , ... }
=end

  def create_general_class classes
    begin
      get_database_classes requery: true
      consts = Array.new
      execute transaction: false do
        class_cmd = -> (s,n) do
      	  n = n.to_s.camelize
      	  consts << ActiveOrient::Model.orientdb_class(name: n)
          classes_available = get_database_classes.map{|x| x.downcase}
      	  unless classes_available.include?(n.downcase)
      	    {type: "cmd", language: 'sql', command: "create class #{n} extends #{s}"}
          end
    	  end  ## class_cmd

    	  if classes.is_a?(Array)
    	    classes.map do |n|
    	      n = n.to_s.camelize
    	      consts << ActiveOrient::Model.orientdb_class(name: n)
            classes_available = get_database_classes.map{|x| x.downcase}
        	  unless classes_available.include?(n.downcase)
    		      {type: "cmd", language: 'sql', command: "create class #{n}"}
    	      end
    	    end
    	  elsif classes.is_a?(Hash)
    	    classes.keys.map do |superclass|
    	      items = Array.new
    	      superClass = superclass.to_s.camelize
            unless get_database_classes.flatten.include?(superClass)
    	        items << {type: "cmd", language: 'sql', command:  "create class #{superClass} abstract"}
            end
    	      items << if classes[superclass].is_a?(String) || classes[superclass].is_a?(Symbol)
    		      class_cmd[superClass, classes[superclass]]
    	      elsif classes[superclass].is_a?(Array)
    		      classes[superclass].map{|n| class_cmd[superClass, n]}
    	      end
            items  # returnvalue
    	    end.flatten
    	  end.compact # erase nil-entries, in case the class is already allocated
      end
    # refresh cached class-informations
      get_database_classes requery: true
    # returns an array of allocated Constants/Classes
      consts
    rescue RestClient::InternalServerError => e
      logger.progname = 'RestCreate#CreateGeneralClass'
      response = JSON.parse(e.response)['errors'].pop
      logger.error{"#{response['content'].split(':').last }"}
      nil
    end
  end
  alias create_classes create_general_class

# Creates a class and returns the a ActiveOrient::Model:{Newclass}-Class- (Constant) which is designed to take any documents stored in this class

  def create_record_class newclass
    create_general_class([newclass]).first
  end
  alias open_class create_record_class
  alias create_class create_record_class
  alias create_document_class create_record_class

  def create_vertex_class name, superclass: 'V'
    create_general_class({superclass => name}).first
  end

  def create_edge_class name, superclass: 'E'
    create_general_class({superclass => name}).first
  end

  ############## OBJECT #############

=begin
  create_edge connects two vertexes
  The parameter o_class can be either a class or a string
=end

  def create_edge o_class, attributes: {}, from:, to:, unique: false
    logger.progname = "ActiveOrient::RestCreate#CreateEdge"
    if from.is_a? Array
  	  from.map{|f| create_edge o_class, attributes: attributes, from: f, to: to, unique: unique}
    elsif to.is_a? Array
  	  to.map{|t| create_edge o_class, attributes: attributes, from: from, to: t, unique: unique}
    else
    	if unique
    	  wwhere = {out: from.to_orient, in: to.to_orient }.merge(attributes.to_orient)
    	  existing_edge = get_records(from: o_class, where: wwhere)
    	  if existing_edge.first.is_a?(ActiveOrient::Model)
    	    #logger.debug {"Reusing edge #{classname(o_class)} from #{from.to_orient} to #{to.to_orient}"}
    	    return existing_edge.first
    	  end
    	end
    	#logger.debug {"Creating edge #{classname(o_class)} from #{from.to_orient} to #{to.to_orient}"}
    	response = execute(o_class, transaction: false) do
    	  attr_string =  attributes.blank? ? "" : "set #{generate_sql_list attributes.to_orient}"
    	  [{ type: "cmd",
          language: 'sql',
          command: "create edge #{classname(o_class)} from #{from.to_orient} to #{to.to_orient} #{attr_string}"}]
    	end
    	if response.is_a?(Array) && response.size == 1
    	  response.pop # RETURN_VALUE
    	else
    	  response
    	end
    end
  end

=begin
  Creates a Record (NOT edge) in the Database and returns this as ActiveOrient::Model-Instance
  Creates a Record with the attributes provided in the attributes-hash e.g.
   create_record @classname, attributes: {con_id: 343, symbol: 'EWTZ'}

  untested: for hybrid and schema-less documents the following syntax is supported
   create_document Account, attributes: {date: 1350426789, amount: 100.34,		       "@fieldTypes" => "date = t, amount = c"}

  The supported special types are:
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

  def create_record o_class, attributes: {}
    logger.progname = 'RestCreate#CreateRecord'
    attributes = yield if attributes.empty? && block_given?
    post_argument = {'@class' => classname(o_class)}.merge(attributes).to_orient

    begin
      response = @res[document_uri].post post_argument.to_json
      data = JSON.parse(response.body)
      ActiveOrient::Model.orientdb_class(name: data['@class']).new data
    rescue RestClient::InternalServerError => e
      response = JSON.parse(e.response)['errors'].pop
      logger.error{response['content'].split(':')[1..-1].join(':')}
      logger.error{"No Object allocated"}
      nil # return_value
    end
  end
  alias create_document create_record

=begin
  Creating a new Database-Entry (where is omitted)
  Or updating the Database-Entry (if present)

  The optional Block should provide a hash with attributes (properties). These are used if a new dataset is created.

  Based on the query specified in :where records are updated according to :set

  Returns an Array of updated documents
=end

  def update_or_create_records o_class, set: {}, where: {}, **args, &b
    logger.progname = 'RestCreate#UpdateOrCreateRecords'
    if where.blank?
      r = create_record(o_class, attributes: set)
    else
  	  set.extract!(where.keys) # removes any keys from where in set
  	  possible_records = get_records from: classname(o_class), where: where, **args
    	if possible_records.empty?
    	  if block_given?
    	    more_where = yield   # do Preparations prior to the creation of the dataset
          # if the block returns a Hash, it is merged into the insert_query.
    	    where.merge! more_where if more_where.is_a?(Hash)
    	  end
    	  r = create_record(o_class, attributes: set.merge(where))
    	else
    	  r = possible_records.map{|doc| doc.update(set: set)}
    	end
    end
  end
  alias create_or_update_record update_or_create_records
  alias create_or_update_document update_or_create_records
  alias update_or_create_documents update_or_create_records

  ############### PROPERTIES #############

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

  def create_properties o_class, all_properties, &b
    logger.progname = 'RestCreate#CreatePropertes'
    all_properties_in_a_hash = HashWithIndifferentAccess.new
    all_properties.each{|field, args| all_properties_in_a_hash.merge! translate_property_hash(field, args)}
    begin
  	  count = if all_properties_in_a_hash.is_a?(Hash)
    	  response = @res[property_uri(classname(o_class))].post all_properties_in_a_hash.to_json
    	  if response.code == 201
    	    response.body.to_i
    	  else
    	    0
    	  end
    	end
      rescue RestClient::InternalServerError => e
  	    response = JSON.parse(e.response)['errors'].pop
  	    error_message = response['content'].split(':').last
        logger.error{"Properties in #{classname(o_class)} were NOT created"}
  	    logger.error{"Error-code #{response['code']} --> #{response['content'].split(':').last }"}
  	    nil
      end
        ### index
      if block_given? && count == all_properties_in_a_hash.size
  	    index = yield
  	    if index.is_a?(Hash)
  	      if index.size == 1
  	        create_index o_class, name: index.keys.first, on: all_properties_in_a_hash.keys, type: index.values.first
  	      else
  	        index_hash =  HashWithIndifferentAccess.new(type: :unique, on: all_properties_in_a_hash.keys).merge index
  	        create_index o_class, index_hash # i [:name], on: index_hash[:on], type: index_hash[:type]
  	      end
  	    end
      end
    count  # return_value
  end

=begin
  Create a single property on class-level.
  Supported types: https://orientdb.com/docs/last/SQL-Create-Property.html
  If index is to be specified, it's defined in the optional block
      create_property(class, field){:unique | :notunique}	                    --> creates an automatic-Index on the given field
      create_property(class, field){{»name« => :unique | :notunique | :full_text}} --> creates a manual index
=end

  def create_property o_class, field, index: nil, **args
    logger.progname = 'RestCreate#CreateProperty'
  	c = create_properties o_class, {field => args}
  	if index.nil? && block_given?
  	  index = yield
  	end
  	if c == 1 && index.present?
  	  if index.is_a?(String) || index.is_a?(Symbol)
  	    create_index o_class, name: field, type: index
  	  elsif index.is_a? Hash
  	    bez = index.keys.first
        create_index o_class, name: bez, type: index[bez], on: [field]
      end
  	end
  end

  ################# INDEX ###################

# Used to create an index

  def create_index o_class, name:, on: :automatic, type: :unique
    logger.progname = 'RestCreate#CreateIndex'
    begin
      c = classname o_class
      execute transaction: false do
    	  command = if on == :automatic
    		  "create index #{c}.#{name} #{type.to_s.upcase}"
    		elsif on.is_a? Array
    		  "create index #{name} on #{classname(o_class)}(#{on.join(', ')}) #{type.to_s.upcase}"
    		else
    		  nil
    		end
    	  [{type: "cmd", language: 'sql', command: command}]
      end
      logger.info{"Index on #{c} based on #{name} created."}
    rescue RestClient::InternalServerError => e
      response = JSON.parse(e.response)['errors'].pop
  	  error_message = response['content'].split(':').last
      logger.error{"Index not created."}
      logger.error{"Error-code #{response['code']} --> #{response['content'].split(':').last }"}
      nil
    end
  end

end
