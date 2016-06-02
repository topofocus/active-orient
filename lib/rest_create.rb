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
      response = @res["database/#{@database}/#{type}"].post ""
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

def create_general_class classes, behaviour: "NORMALCLASS", extended_class: nil, properties: nil
  if @classes.empty?
    @classes = get_database_classes requery: true
  end

  begin
    consts = Array.new

    if classes.is_a? Array
      classes.each do |singleclass|
        consts |= create_general_class singleclass, behaviour: behaviour, extended_class: extended_class, properties: properties
      end

    elsif classes.is_a? Hash
      classes.keys.each do |superclass|
        create_general_class superclass, behaviour: "SUPERCLASS", extended_class: nil, properties: nil
        consts |= create_general_class classes[superclass], behaviour: "EXTENDEDCLASS", extended_class: superclass, properties: properties
      end

    else
      name_class = classes.to_s.capitalize_first_letter
      unless @classes.downcase.include?(name_class.downcase)

        if behaviour == "NORMALCLASS"
          command = "CREATE CLASS #{name_class}"
        elsif behaviour == "SUPERCLASS"
          command = "CREATE CLASS #{name_class} ABSTRACT"
        elsif behaviour == "EXTENDEDCLASS"
          name_superclass = extended_class.to_s
          command = "CREATE CLASS #{name_class} EXTENDS #{name_superclass}"
        end

        #print "\n #{command} \n"

        execute transaction: false do
          [{ type:    "cmd",
            language: "sql",
            command:  command}]
        end

        @classes << name_class

        # Add properties
        unless properties.nil?
          create_properties name_class, properties
        end
      end

      consts << ActiveOrient::Model.orientdb_class(name: name_class)
    end

  return consts

  rescue RestClient::InternalServerError => e
    logger.progname = 'RestCreate#CreateGeneralClass'
    response = JSON.parse(e.response)['errors'].pop
    logger.error{"#{response['content'].split(':').last }"}
    nil
  end
end
alias create_classes create_general_class

# Creates a class and returns the a ActiveOrient::Model:{Newclass}-Class- (Constant) which is designed to take any documents stored in this class

  def create_record_class newclass, properties: nil
    create_general_class([newclass], properties: properties).first
  end
  alias open_class create_record_class
  alias create_class create_record_class
  alias create_document_class create_record_class

  def create_vertex_class name, superclass: 'V', properties: nil
    create_general_class({superclass => name}, properties: properties).first
  end

  def create_edge_class name, superclass: 'E', properties: nil
    create_general_class({superclass => name}, properties: properties).first
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
    	  attr_string =  attributes.blank? ? "" : "SET #{generate_sql_list attributes.to_orient}"
    	  [{ type: "cmd",
          language: 'sql',
          command: "CREATE EDGE #{classname(o_class)} FROM #{from.to_orient} TO #{to.to_orient} #{attr_string}"}]
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
      response = @res["/document/#{@database}"].post post_argument.to_json
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
  Used to create multiple records at once
  For example:
    $r.create_multiple_records "Month", ["date", "value"], [["June", 6], ["July", 7], ["August", 8]]
  It is equivalent to this three functios:
    $r.create_record "Month", attributes: {date: "June", value: 6}
    $r.create_record "Month", attributes: {date: "July", value: 7}
    $r.create_record "Month", attributes: {date: "August", value: 8}

  The function $r.create_multiple_records "Month", ["date", "value"], [["June", 6], ["July", 7], ["August", 8]] will return an array with three element of class "Active::Model::Month".
=end

  def create_multiple_records o_class, values, new_records
    command = "INSERT INTO #{o_class} ("
    values.each do |val|
      command += "#{val},"
    end
    command[-1] = ")"
    command += " VALUES "
    new_records.each do |new_record|
      command += "("
      new_record.each do |record_value|
        case record_value
        when String
          command += "\'#{record_value}\',"
        when Integer
          command += "#{record_value},"
        when ActiveOrient::Model
          command += "##{record_value.rid},"
        when Array
          if record_value[0].is_a? ActiveOrient::Model
            command += "["
            record_value.rid.each do |rid|
              command += "##{rid},"
            end
            command[-1] = "]"
            command += ","
          else
            command += "null,"
          end
        else
          command += "null,"
        end
      end
      command[-1] = ")"
      command += ","
    end
    command[-1] = ""
    execute classname(o_class), transaction: false do # To execute commands
      [{ type: "cmd",
        language: 'sql',
        command: command}]
    end
  end

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
      [create_record(o_class, attributes: set)]
    else
  	  set.extract!(where.keys) # removes any keys from where in set
  	  possible_records = get_records from: classname(o_class), where: where, **args
    	if possible_records.empty?
    	  if block_given?
    	    more_where = yield   # do Preparations prior to the creation of the dataset
          # if the block returns a Hash, it is merged into the insert_query.
    	    where.merge! more_where if more_where.is_a?(Hash)
    	  end
    	  [create_record(o_class, attributes: set.merge(where))]
    	else
    	  possible_records.map{|doc| doc.update(set: set)}
    	end
    end
  end

  def update_or_create_a_record o_class, set: {}, where: {},   **args, &b
    result = update_or_create_records( o_class, set: set, where: where, **args, &b) 
    result.first
  end

  alias create_or_update_document update_or_create_a_record
  alias update_or_create_documents update_or_create_records
  alias update_or_create update_or_create_records

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
    logger.progname = 'RestCreate#CreateProperties'
    all_properties_in_a_hash = HashWithIndifferentAccess.new
    all_properties.each{|field, args| all_properties_in_a_hash.merge! translate_property_hash(field, args)}
    count=0
    begin
      if all_properties_in_a_hash.is_a?(Hash)
	response = @res["/property/#{@database}/#{classname(o_class)}"].post all_properties_in_a_hash.to_json
	# response.body.to_i returns  response.code, only to_f.to_i returns the correrect value
	count= response.body.to_f.to_i if response.code == 201
      end
    rescue RestClient::InternalServerError => e
      response = JSON.parse(e.response)['errors'].pop
      error_message = response['content'].split(':').last
      logger.error{"Properties in #{classname(o_class)} were NOT created"}
      logger.error{"#{response['content'].split(':').last}"}
      nil
    end
        ### index
    if block_given? && count == all_properties_in_a_hash.size
      puts "creat_rest#create_properties##index detected"
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

  def create_property o_class, field, index: nil, **args, &b
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
    		  "CREATE INDEX #{c}.#{name} #{type.to_s.upcase}"
    		elsif on.is_a? Array
    		  "CREATE INDEX #{name} ON #{classname(o_class)}(#{on.join(', ')}) #{type.to_s.upcase}"
    		else
    		  "CREATE INDEX #{name} ON #{classname(o_class)}(#{on.to_s}) #{type.to_s.upcase}"
    		  #nil
    		end
	  puts "command: #{command}"
    	  [{type: "cmd", language: 'sql', command: command}] if command.present?
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
