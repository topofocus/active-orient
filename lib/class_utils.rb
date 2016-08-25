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
	      logger.warn{ "Classname #{name_or_class.inspect} ://: #{name} not present in #{ActiveOrient.database}" }
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
    # if multible classes are specified, don't process properties
    # ( if multible classes need the same properties, consider a nested class-design )
   if the_class.is_a?(Array)
     if the_class.size == 1
       the_class = the_class.first
     else
       properties =  nil
     end
    end
   create_properties( the_class.ref_name , properties )  if properties.present?
   the_class # return_value
 end


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

def allocate_classes_in_ruby classes  # :nodoc:
    generate_ruby_object = ->( name, superclass, abstract ) do
      begin
	# if the class is prefined, use specs from get_classes
	or_def =  get_classes('name', 'superClass', 'abstract' ).detect{|x| x['name']== name }
	superclass, abstract = or_def.reject{|k,v| k=='name'}.values unless or_def.nil?
      #print "GENERATE_RUBY_CLASS: #{name} / #{superclass}"
	 m= ActiveOrient::Model.orientdb_class name: name,  superclass: superclass
	 m.abstract = abstract
     # puts "-->  #{m.object_id}"
	 m
      rescue NoMethodError => w
	logger.progname = "Allocate_Classes_in_Ruby"
	logger.error{ "Trying to redefine an existing class: #{name}: ALLOCATION FAILED "}
	nil
#	raise
      end 

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
      next_superclass=  superclass
      classes.map do |singleclass|
	if singleclass.is_a?( String) || singleclass.is_a?( Symbol)
	next_superclass = generate_ruby_object[singleclass,superclass,abstract]
	elsif singleclass.is_a?(Array) || singleclass.is_a?(Hash) 
	  allocate_classes_in_ruby( singleclass){ {superclass: next_superclass, abstract: abstract}}
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
#    consts.unshift superclass_object if superclass_object.present?  rescue [ superclass_object, consts ]
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

  The parameter o_class can be either a class or a string

  if batch is specified, the edge-statement is prepared and returned 
  else the statement is transmitted to the database

  The method takes a block as well. 
  It must provide a Hash with :from and :to- Key's, e.g.
  Vertex1, Vertex2 are two vertex-classes and TheEdge is an edge-class

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
  def create_edge o_class, attributes: {}, from:nil, to:nil, unique: false, batch: nil  
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
#		  puts record.inspect
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
#      puts "COMMAND: #{command.inspect}"
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
	puts "ArgumentError "
	puts e.inspect
      end  # begin
    end

  end
	def remove_record_from_hash r
	  obj= ActiveOrient::Base.get_rid(r.rid) unless r.nil?
	  ActiveOrient::Base.remove_rid( obj ) unless obj.nil?
	end

end # module
