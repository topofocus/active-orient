module ClassUtils

=begin
  Returns a valid database-class name, nil if the class does not exists
=end

  def classname name_or_class
    name = case  name_or_class
	when ActiveOrient::Model
              name_or_class.class.ref_name
	when Class
              name_or_class.ref_name
#	      name_or_class.to_s.split('::').last
	else
	  name_or_class.to_s #.to_s.camelcase # capitalize_first_letter
    end
    ## 16/5/31  : reintegrating functionality to check wether the classname is 
    #		  present in the database or not
          if database_classes.include?(name)
	             name
	  elsif database_classes.include?(name.underscore)
	           name.underscore
	  else
	     logger.progname =  'ClassUtils#Classname'
	      logger.warn{ "Classname #{name_or_class.inspect} ://: #{name} not present in active Database" }
	  nil

	  end
  end
=begin
create a single class and provide properties as well

  ORB.create_class( the_class_name as String or Symbol (nessesary) ,
		    properties: a Hash with property- and Index-descriptions (optional)){
		    {superclass: The name of the superclass as String or Symbol , 
		     abstract: true|false } (optional Block provides a Hash ) }

=end
 def create_class classname, properties: nil, &b
   the_class= create_classes( classname, &b )
   create_properties( the_class.ref_name , properties )  if properties.present?
   the_class # return_value
 end

  alias open_class create_class
  alias create_document_class create_class


=begin
  Creates classes and class-hierarchies in OrientDB and in Ruby.
  Takes a String,  Array or Hash as argument and returns a (nested) Array of
  successfull allocated Ruby-Classes.
  If a block is provided, this is used to allocate the class to this superclass.

  Examples

    create_class  "a_single_class"
    create_class  :a_single_class
    create_class(  :a_single_class ){ :a_super_class }
    create_class(  :a_single_class ){ superclass: :a_super_class, abstract: true }
    create_class( ["c",:l,:A,:SS] ){ :V } --> vertices
    create_class( ["c",:l,:A,:SS] ){ superclass: :V, abstract: true } --> abstract vertices
    create_class( { V: [ :A, :B, C: [:c1,:c3,:c2]  ],  E: [:has_content, :becomes_hot ]} )
=end

def allocate_classes_in_ruby classes
    generate_ruby_object = ->( name, superclass, abstract ) do
	 m= ActiveOrient::Model.orientdb_class name: name,  superclass: superclass
	 m.abstract = abstract
	 m
    end

    superclass, abstract  = if block_given? 
			      s =  yield
			      if s.is_a? Hash
				[s[:superclass],s[:abstract]]
				else
				  [s,false]
			      end
			    else
			      [nil,false]
			    end
    superclass_object = generate_ruby_object[superclass,nil,nil] if superclass.present?

    consts = case classes 
    when  Array
      classes.map do |singleclass|
	if singleclass.is_a?( String) || singleclass.is_a?( Symbol)
	generate_ruby_object[singleclass,superclass,abstract]
	elsif singleclass.is_a?(Array) || singleclass.is_a?(Hash) 
	  allocate_classes_in_ruby( singleclass){ {superclass: superclass, abstract: abstract}}
	end
      end
    when Hash
      classes.keys.map  do| h_superclass |
[	generate_ruby_object[h_superclass,superclass,abstract], 
        allocate_classes_in_ruby(classes[ h_superclass ]){{ superclass: h_superclass, abstract: abstract }} ]
      end
    when String, Symbol
      generate_ruby_object[classes,superclass, abstract]
    end
    consts.unshift superclass_object if superclass_object.present?  rescue [ superclass_object, consts ]
    consts
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
  	  set.extract!(where.keys) if where.is_a?(Hash) # removes any keys from where in set
  	  possible_records = get_records from: classname(o_class), where: where, **args
    	if possible_records.empty?
    	  if block_given?
    	    more_where = yield   # do Preparations prior to the creation of the dataset
          # if the block returns a Hash, it is merged into the insert_query.
    	    where.merge! more_where if more_where.is_a?(Hash)
    	  end
    	  [create_record(o_class, attributes: set.merge(where))]
    	else
    	  possible_records.map{|doc| doc.update(set: set)} unless set.empty?
    	end
    end
  end

  def update_or_create_a_record o_class, set: {}, where: {},   **args, &b
    result = update_or_create_records( o_class, set: set, where: where, **args, &b) 
    puts "Attention: update_or_create_a_record is depriciated"
    result.first
  end

  alias create_or_update_document update_or_create_a_record
  alias update_or_create_documents update_or_create_records
  alias update_or_create update_or_create_records


  def create_edge o_class, attributes: {}, from:nil, to:nil, unique: false, batch: nil
    logger.progname = "ActiveOrient::RestCreate#CreateEdge"

    if block_given?
      a =  yield(attributes)
      command = if a.is_a? Array
       a.map do | record | 
	this_attributes =  record[:attributes].present? ? record[:attributes] : attributes
       
       # in batch-mode unique is not supportet	
       create_edge o_class, attributes: this_attributes, from: record[:from], to: record[:to], unique: false, batch: true
      end
      else
	create_edge o_class, attributes: attributes, from: a[:from], to: a[:to], unique: a[:uniq], batch: true
      end
    elsif from.is_a? Array
      command = from.map{|f| create_edge o_class, attributes: attributes, from: f, to: to, unique: unique, batch: true}
    elsif to.is_a? Array
      command = to.map{|t| create_edge o_class, attributes: attributes, from: from, to: t, unique: unique, batch: true}
    elsif from.present? && to.present?
      if unique
	wwhere = {out: from.to_orient, in: to.to_orient }.merge(attributes.to_orient)
	existing_edge = get_records(from: o_class, where: wwhere)
	if existing_edge.first.is_a?(ActiveOrient::Model)
	  #logger.debug {"Reusing edge #{classname(o_class)} from #{from.to_orient} to #{to.to_orient}"}
	  existing_edge.first
	else
	  existing_edge
	end
      #logger.debug {"Creating edge #{classname(o_class)} from #{from.to_orient} to #{to.to_orient}"}
    elsif from.to_orient.nil? || to.to_orient.nil? 
      logger.error{ "Parameter :from or :to is missing"}
    else
      attr_string =  attributes.blank? ? "" : "SET #{generate_sql_list attributes.to_orient}"
      command = { type: "cmd",
	  language: 'sql',
	  command: "CREATE EDGE #{classname(o_class)} FROM #{from.to_orient} TO #{to.to_orient} #{attr_string}"
		      }
      end
    else 
      # for or to are not set
      return nil
    end
    if batch.nil?
      response = execute(transaction: false) do
	command.is_a?(Array) ? command.flatten.compact : [ command ]
      end
      if response.is_a?(Array) && response.size == 1
	response.pop # RETURN_VALUE
      else
	response  # return value (the normal case)
      end
    else
      command # return value (if batch)
    end
  end

end # module
