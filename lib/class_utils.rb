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
			superclass =  if s.present?     # get the superclass recusivly
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

  ORD.create_class( class ) { {superclass: the_superclass_name, abstract: true_or_false } } 

  ORD.create_class class

=end
	def create_class( *class_names, properties: nil, &b )


		if block_given?
			the_block =  yield
			superclass, abstract = if the_block.is_a? Class
															 [ the_block, nil ]
														 elsif the_block.is_a?(String) || the_block.is_a?(Symbol)
															 [ ActiveOrient.database_classes[the_block] , nil ]
														 elsif the_block.is_a?(Hash)
															 [ ActiveOrient.database_classes[the_block[:superclass]], 
									ActiveOrient.database_classes[the_block[:abstract]] ]
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
Deletes the specified edges and unloads referenced vertices from the cache
=end
  def delete_edge *edge

    edge.each do |r|
      [r.in, r.out].each{| e | remove_record_from_hash e}
      remove_record_from_hash r
    end
	  execute{ "DELETE EDGE #{edge.map{|x| x.to_orient }.join(',')} "}
  end

  private
	def remove_record_from_hash r
	  obj= ActiveOrient::Base.get_rid(r.rid) unless r.nil?
	  ActiveOrient::Base.remove_rid( obj ) unless obj.nil?
	end

end # module
