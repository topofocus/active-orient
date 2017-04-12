module ClassUtils
  # ClassUitils is included in Rest- and Java-Api-classes

=begin
  Returns a valid database-class name, nil if the class does not exists
=end

  def classname name_or_class  # :nodoc:
    name = case  name_or_class
	   when ActiveOrient::Model
	     name_or_class.class.ref_name 
	   when Class
	     ActiveOrient.database_classes.key(name_or_class)
	   else
	     if ActiveOrient.database_classes.has_key?( name_or_class.to_s )
	       name_or_class 
	     else
	       logger.progname =  'ClassUtils#Classname'
	       logger.warn{ "Classname #{name_or_class.inspect} ://: #{name} not present in #{ActiveOrient.database}" }
	       nil
	     end
	   end
  end
  def allocate_class_in_ruby db_classname, &b
    # retrieve the superclass recursively

    unless ActiveOrient.database_classes[ db_classname ].is_a? Class

      s = get_db_superclass( db_classname )
      superclass =  if s.present? 
		      allocate_class_in_ruby( s, &b ) 
		    else
		      ActiveOrient::Model
		    end
      # superclass is nil, if allocate_class_in_ruby is recursivley
      # called and the superclass was not established
      if superclass.nil?
	ActiveOrient.database_classes[ db_classname ] = "Superclass model file missing"
	return
      end
      reduced_classname =  superclass.namespace_prefix.present? ? db_classname.split( superclass.namespace_prefix ).last :  db_classname
      classname =  superclass.naming_convention(  reduced_classname )

      the_class = if !( ActiveOrient::Model.namespace.send :const_defined?, classname, false )
		    ActiveOrient::Model.namespace.send( :const_set, classname, Class.new( superclass ) )
		  elsif ActiveOrient::Model.namespace.send( :const_get, classname).ancestors.include?( ActiveOrient::Model )
		    ActiveOrient::Model.namespace.send( :const_get, classname)
		  else
		    t= ActiveOrient::Model.send :const_set, classname, Class.new( superclass )
		    logger.warn{ "Unable to allocate class #{classname} in Namespace #{ActiveOrient::Model.namespace}"}
		    logger.warn{ "Allocation took place with namespace ActiveOrient::Model" }
		    t
		  end
      the_class.ref_name = db_classname
      keep_the_dataset = block_given? ? yield( the_class ) : true
      if keep_the_dataset 
	ActiveOrient.database_classes[db_classname] = the_class 
	the_class.ref_name =  db_classname
	the_class #  return the generated class
      else
	unless ["E","V"].include? classname  # never remove Base-Classes!
	  base_classname =  the_class.to_s.split("::").last.to_sym

	  if ActiveOrient::Model.namespace.send( :const_defined? , classname)
	    ActiveOrient::Model.namespace.send( :remove_const, classname )
	  else
	    ActiveOrient::Model.send( :remove_const, classname)
	  end
	end
	nil  # return-value
      end
    else
      # return previosly allocated ruby-class
      ActiveOrient.database_classes[db_classname] 
    end
  end

=begin
create a single class and provide properties as well

   ORD.create_class( the_class_name as String or Symbol (nessesary) ,
		    properties: a Hash with property- and Index-descriptions (optional)) do
		    { superclass: The name of the superclass as String or Symbol , 
		      abstract: true|false 
		      } 
		     end

  or

  ORD.create_class( class1, class2 ... ) { Superclass } 

  or

  ORD.create_class class

=end
  def create_class( *class_names, properties: nil, &b )
    

    if block_given?
      the_block =  yield
      if the_block.is_a? Class
	superclass = the_block
      elsif the_block.is_a?(String) || the_block.is_a?(Symbol)
	superclass = ActiveOrient.database_classes[the_block.to_s] 
      elsif the_block.is_a?(Hash)
	superclass =  ActiveOrient.database_classes[the_block[:superclass]]
	abstract =  ActiveOrient.database_classes[the_block[:abstract]]
      end
    end
    superclass =  superclass.presence ||  ActiveOrient::Model
  
    
    r= class_names.map do | the_class_name |
      the_class_name =  superclass.namespace_prefix + the_class_name.to_s 

      ## lookup the database_classes-Hash
      if ActiveOrient.database_classes[the_class_name].is_a?(Class)
	ActiveOrient.database_classes[the_class_name] 
      else
	if superclass =="" || superclass.ref_name == ""
	  create_this_class the_class_name 
	else
	  create_this_class( the_class_name ) do
	    if the_block.is_a?(Hash) 
	      the_block[:superclass] = superclass.ref_name
	      the_block
	    else
	      { superclass: superclass.ref_name }
	    end
	  end
	end
	database_classes  # update_class_array
	create_properties( the_name , properties )  if properties.present?
	allocate_class_in_ruby( the_class_name ) do |that_class| 
	  keep_the_dataset =  true
	end
      end
    end
    r.size==1 ? r.pop : r  # return a single class or an array of created classes
  end

=begin
Creates one or more vertex-classes and allocates the provided properties to each class.

  ORD.create_vertex_class :a
  => A
  ORD.create_vertex_class :a, :b, :c
  => [A, B, C]
=end

  def create_vertex_class *name, properties: nil 
    r= name.map{|n| create_class( n, properties: properties){ V } }
    r.size == 1 ? r.pop : r
  end
=begin
Creates one or more edge-classes and allocates the provided properties to each class.
=end

  def create_edge_class *name,  properties: nil
    r = name.map{|n| create_class( n.to_s, properties: properties){ E  } }
    r.size == 1 ? r.pop : r  # returns the created classes as array if multible classes are provided
  end
=begin
- Creating a new Database-Entry (where is omitted)
 - Updating the Database-Entry (if present)

  The optional Block should provide a hash with attributes (properties). These are used if a new dataset is created.
  Based on the query specified in »:where« records are updated according to »:set«.

  Returns an Array of updated documents
=end

  def update_or_create_records( o_class, set: {}, where: {}, **args, &b )
    logger.progname = 'ClassUtils#UpdateOrCreateRecords'
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


=begin
  create_edge connects two vertexes

  The parameter _o_class_ can be either a class or a string.

  If batch is specified, the edge-statement is prepared and returned.
  Otherwise the statement is transmitted to the database.

  The method takes a block as well. 
  It must provide a Hash with :from and :to- Key's.

  Suppose »Vertex1«, »Vertex2« are two vertex-classes and »TheEdge« is an edge-class

      record1 = ( 1 .. 100 ).map{ |y| Vertex1.create( testentry: y } }
      record2 = ( :a .. :z ).map{ |y| Vertex2.create( testentry: y } }

      edges = ORD.create_edge( TheEdge ) do | attributes |
	 ('a'.ord .. 'z'.ord).map do |o| 
	       { from: record1.find{|x| x.testentry == o },
		 to:   record2.find{ |x| x.testentry.ord == o },
		 attributes: attributes.merge{ key: o.chr } }
	  end
  or

      edges = ORD.create_edge( TheEdge ) do | attributes |
	 ('a'.ord .. 'z'.ord).map do |o| 
	       { from: Vertex1.where( testentry:  o ).pop ,
		 to:   Vertex2.where( testentry.ord =>  o).pop ,
		 attributes: attributes.merge{ key: o.chr } }
	  end

  Benefits: The statements are transmitted as batch.

  The pure-ruby-solution minimizes traffic to the database-server and is prefered.

=end
  def create_edge( o_class, attributes: {}, from:nil, to:nil, unique: false, batch: nil )
    logger.progname = "ClassUtils#CreateEdge"

# -------------------------------
    create_command =  -> (attr, from, to ) do
      attr_string =  attr.blank? ? "" : "SET #{generate_sql_list attr}"
      if from.present? && to.present? 
      [from, to].each{|y| remove_record_from_hash y }
      { type: "cmd",
	  language: 'sql',
	  command: "CREATE EDGE #{classname(o_class)} FROM #{from.to_orient} TO #{to.to_orient} #{attr_string}"
		      }
      end
    end
# -------------------------------

    if block_given?
      a =  yield(attributes)
      command = if a.is_a? Array
		  batch =  nil
		  command=  a.map do | record | 
		    this_attributes =  record[:attributes].presence || attributes
		    create_command[ this_attributes, record[:from],  record[:to]]
		  end
		else
		  this_attributes =  a[:attributes].presence || attributes
		  command = create_command[ this_attributes, a[:from],  a[:to]]
		end
    elsif from.is_a?( Array ) && to.is_a?(Array)
      command = Array.new
      while from.size >1
	this_attributes = attributes.is_a?(Array) ? attributes.shift : attributes
	command << create_command[ this_attributes, from.shift, to.shift]
      end
    elsif from.is_a? Array
      command = from.map{|f| create_command[ attributes, f, to] }
    elsif to.is_a? Array
      command = to.map{|f| create_command[ attributes, from, f] }
    elsif from.present? && to.present?
      #      if unique
      #	wwhere = {out: from.to_orient, in: to.to_orient }.merge(attributes.to_orient)
      #	existing_edge = get_records(from: o_class, where: wwhere)
      #	if existing_edge.size >1 
      #	  logger.error{ "Unique specified, but there are #{existing_edge.size} Records in the Database. returning the first"}
      #	  command =  existing_edge.first
      #	  batch = true
      #	elsif existing_edge.size ==1  && existing_edge.first.is_a?(ActiveOrient::Model)
      #	  #logger.debug {"Reusing edge #{classname(o_class)} from #{from.to_orient} to #{to.to_orient}"}
      #	  command=  existing_edge.first
      #	  batch= true
      #	else
      command = create_command[ attributes, from, to]
      #	end
      #	#logger.debug {"Creating edge #{classname(o_class)} from #{from.to_orient} to #{to.to_orient}"}
      #
    elsif from.to_orient.nil? || to.to_orient.nil? 
      logger.error{ "Parameter :from or :to is missing"}
    else 
      # for or to are not set
      return nil
    end
#   puts "RUNNING EDGE: #{command.inspect}"
    if command.present?
      begin
	response = execute(transaction: false, tolerated_error_code: /found duplicated key/) do
	  command.is_a?(Array) ? command.flatten.compact : [ command ]
	end
	if response.is_a?(Array) && response.size == 1
	  response.pop # RETURN_VALUE
	else
	  response  # return value (the normal case)
	end
      rescue ArgumentError => e
	puts "CreateEdge:ArgumentError "
	puts e.inspect
      end  # begin
    end

  end
=begin
Deletes the specified vertices and unloads referenced edges from the cache
=end
  def delete_vertex *vertex
    create_command =  -> do
      { type: "cmd",
	  language: 'sql',
	  command: "DELETE VERTEX #{vertex.map{|x| x.to_orient }.join(',')} "
		      }
      end

    vertex.each{|v| v.edges.each{| e | remove_record_from_hash e} }
    execute{ create_command[] }
  end

=begin
Deletes the specified edges and unloads referenced vertices from the cache
=end
  def delete_edge *edge
    create_command =  -> do
      { type: "cmd",
	  language: 'sql',
	  command: "DELETE EDGE #{edge.map{|x| x.to_orient }.join(',')} "
		      }
      end

    edge.each do |r|
      [r.in, r.out].each{| e | remove_record_from_hash e}
      remove_record_from_hash r
    end
    execute{ create_command[] }
  end

  private
	def remove_record_from_hash r
	  obj= ActiveOrient::Base.get_rid(r.rid) unless r.nil?
	  ActiveOrient::Base.remove_rid( obj ) unless obj.nil?
	end

end # module
