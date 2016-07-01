module RestCreate

  ######### DATABASE ##########

=begin
  Creates a database with the given name and switches to this database as working-database. Types are either 'plocal' or 'memory'
  Returns the name of the working-database
=end

  def create_database type: 'plocal', database: nil
    logger.progname = 'RestCreate#CreateDatabase'
  	old_d = ActiveOrient.database
  	ActiveOrient.database_classes = []
  	ActiveOrient.database = database if database.present?
  	begin
      response = @res["database/#{ActiveOrient.database}/#{type}"].post ""
      if response.code == 200
        logger.info{"Database #{ActiveOrient.database} successfully created and stored as working database"}
      else
        ActiveOrient.database = old_d
        logger.error{"Database #{name} was NOT created. Working Database is still #{ActiveOrient.database}"}
      end
    rescue RestClient::InternalServerError => e
      ActiveOrient.database = old_d
      logger.error{"Database #{name} was NOT created. Working Database is still #{ActiveOrient.database}"}
    end
    ActiveOrient.database
  end

  ######### CLASS ##########

=begin 
General method to create database classes
-----------------------------------------
Accepts 
* a string or symbol  
  then creates a single class and returns the ActiveOrient::Model-Class
* an arrray of strings or symbols
  then creates alltogether and returns an array of created ActiveOrient::Model-Classes
* a (nested) Hash 
  then creates a hierarchy of database-classes and returns them as hash

takes an optional block to specify a superclass.
This is NOT retruned 
eg  
  create_classes( :test ){ :V } 
creates a vertex-class, but returns just ActiveOrient::Model::Test
  create_classes( :V => :test)
creates a vertex-class, too, but returns the Hash
=end

    def create_classes classes, &b

      consts = allocate_classes_in_ruby( classes , &b )
      all_classes = consts.is_a?( Array) ? consts.flatten : [consts]
      get_database_classes(requery: true)
      selected_classes =  all_classes.map do | this_class |
	this_class unless database_classes.include?( this_class.ref_name ) rescue nil
      end.compact.uniq
      command= selected_classes.map do | database_class |
	## improper initialized ActiveOrient::Model-classes lack a ref_name class-variable
	next if database_class.ref_name.blank?  
	c = if database_class.superclass == ActiveOrient::Model || database_class.superclass.ref_name.blank?
		    "CREATE CLASS #{database_class.ref_name}" 
		  else
		    "CREATE CLASS #{database_class.ref_name} EXTENDS #{database_class.superclass.ref_name}"
		  end
	c << " ABSTRACT" if database_class.abstract
	{ type: "cmd", language: 'sql', command: c }
	end

	# execute anything as batch, don't roll back in case of an error
	execute transaction: false, tolerated_error_code: /already exists in current database/ do
	  command
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

#        create_general_class singleclass, behaviour: behaviour, extended_class: extended_class, properties: properties

#    when Hash 
#      classes.keys.each do |superclass|
#        create_general_class superclass, behaviour: "SUPERCLASS", extended_class: nil, properties: nil
#        create_general_class classes[superclass], behaviour: "EXTENDEDCLASS", extended_class: superclass, properties: properties
#      end
#
#    else
#      name_class = classes.to_s.capitalize_first_letter
#      unless @classes.downcase.include?(name_class.downcase)
#
#        if behaviour == "NORMALCLASS"
#          command = "CREATE CLASS #{name_class}"
#        elsif behaviour == "SUPERCLASS"
#          command = "CREATE CLASS #{name_class} ABSTRACT"
#        elsif behaviour == "EXTENDEDCLASS"
#          name_superclass = extended_class.to_s
#          command = "CREATE CLASS #{name_class} EXTENDS #{name_superclass}"
#        end
#
#        #print "\n #{command} \n"
#
#        execute transaction: false do
#          [{ type:    "cmd",
#            language: "sql",
#            command:  command}]
#        end
#
#        @classes << name_class
#
#        # Add properties
#        unless properties.nil?
#          create_properties name_class, properties
#        end
#      end
#
#      consts << ActiveOrient::Model.orientdb_class(name: name_class)
#    end

#  return consts
#
#  rescue RestClient::InternalServerError => e
#    logger.progname = 'RestCreate#CreateGeneralClass'
#    response = JSON.parse(e.response)['errors'].pop
#    logger.error{"#{response['content'].split(':').last }"}
#    nil
#  end
#end


  ############## OBJECT #############

=begin
  create_edge connects two vertexes

  The parameter o_class can be either a class or a string

  if batch is specified, the edge-statement is prepared and returned 
  else the statement is transmitted to the database

  The method takes a block as well. 
  It must provide a Hash with :from and :to- Key's, e.g.
      Vertex1, Vertex2 = ActiveOrient::Model:Test1, ActiveOrient::Model::Test2

      record1 = (1 .. 100).map{|y| Vertex1.create_document attributes: { testentry: y  }
      record2 = (:a .. :z).map{|y| Vertex2.create_document attributes:{ testentry: y } }

      edges = ORD.create_edge TheEdge do | attributes |
	 ('a'.ord .. 'z'.ord).map do |o| 
	       { from: record1.find{|x| x.testentry == o },
		 to:   record2.find{ |x| x.testentry.ord == o },
		 attributes: attributes.merge{ key: o.chr } }
	  end
  or

      edges = ORD.create_edge TheEdge do | attributes |
	 ('a'.ord .. 'z'.ord).map do |o| 
	       { from: Vertex1.where( testentry:  o ).pop ,
		 to:   Vertex2.where( testentry.ord =>  o).pop ,
		 attributes: attributes.merge{ key: o.chr } }
	  end

  Benefits: The statements are transmitted as batch.

  The pure-ruby-solution minimizes traffic to the database-server and is prefered.

=end


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
      response = @res["/document/#{ActiveOrient.database}"].post post_argument.to_json
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
    execute  transaction: false do # To execute commands
      [{ type: "cmd",
        language: 'sql',
        command: command}]
    end
  end
# UPDATE <class>|CLUSTER:<cluster>|<recordID>
  #   [SET|INCREMENT|ADD|REMOVE|PUT <field-name> = <field-value>[,]*]|[CONTENT|MERGE <JSON>]
  #     [UPSERT]
  #       [RETURN <returning> [<returning-expression>]]
  #         [WHERE <conditions>]
  #           [LOCK default|record]
  #             [LIMIT <max-records>] [TIMEOUT <timeout>]
=begin
update or insert one record is implemented as upsert.
The where-condition is merged into the set-attributes if its a hash.  
Otherwise it's taken unmodified.

The method returns the included or the updated dataset
=end
  def upsert o_class, set: {}, where: {} 
    logger.progname = 'RestCreate#Upsert'
    if where.blank?
      new_record = create_record(o_class, attributes: set)
      yield new_record if block_given?	  # in case if insert execute optional block
      new_record			  # return_value
    else
       specify_return_value =  block_given? ? "" : "return after @this"
       set.merge! where if where.is_a?( Hash ) # copy where attributes to set 
	command = "Update #{classname(o_class)} set #{generate_sql_list( set ){','}} upsert #{specify_return_value}  #{compose_where where}" 


#	puts "COMMAND: #{command} "
	result = execute  tolerated_error_code: /found duplicated key/ do # To execute commands
	 [ { type: "cmd", language: 'sql', command: command}]
	end 
	result =result.pop if result.is_a? Array

	case result
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
	response = @res["/property/#{ActiveOrient.database}/#{classname(o_class)}"].post all_properties_in_a_hash.to_json
	# response.body.to_i returns  response.code, only to_f.to_i returns the correrect value
	count= response.body.to_f.to_i if response.code == 201
      end
    rescue RestClient::InternalServerError => e
      logger.progname = 'RestCreate#CreateProperties'
      response = JSON.parse(e.response)['errors'].pop
      error_message = response['content'].split(':').last
      logger.error{"Properties in #{classname(o_class)} were NOT created"}
      logger.error{"The Error was: #{response['content'].split(':').last}"}
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
	  create_index o_class, **index_hash # i [:name], on: index_hash[:on], type: index_hash[:type]
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
	  #puts "command: #{command}"
    	  {type: "cmd", language: 'sql', command: command} if command.present?
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
