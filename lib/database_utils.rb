module DatabaseUtils
=begin
returns the classes set by OrientDB

Parameter: 
  abstract: true|false

if abstract: true is given, only basic classes (Abstact-Classes) are returend
=end
	def system_classes abstract: false

		basic=   [  "ORestricted", "OSchedule", "OTriggered", "OSequence"]
		## "ORid" dropped in V2.2
		extended = ["OIdentity","ORole",  "OUser", "OFunction", "_studio"]
		v3 = ["OGeometryCollection", "OLineString", "OMultiLineString", "OMultiPoint", "OMultiPolygon",
		"OPoint", "OPolygon", "ORectangle", "OShape"] ## added in Orentdb 3.0
		if abstract
			basic
		else
			basic + extended + v3
		end
	end
=begin
Returns the class_hierachy

To fetch all Vertices:
   class_hieararchy(base_class: 'V').flatten
To fetch all Edges:
   class_hierarchy(base_class: 'E').flatten
--
notice: 
To retrieve the class hierarchy from Objects avoid calling `ORD.classname (obj)`,  because it depends on class_hierarchy.
=end

	def class_hierarchy base_class: '',  system_classes: nil
		@actual_class_hash = get_classes('name', 'superClass') #if requery || @all_classes.blank?
		fv = ->( s )	{ 	@actual_class_hash.find_all{|x| x['superClass']== s}.map{|v| v['name']} }
		fx = ->( v )  {		fv[v.strip].map{|x| ar = fx[x]; ar.empty? ? x : [x, ar]} }
		if system_classes.present?
			fx[ base_class.to_s ]
		else
			fx[ base_class.to_s ] - system_classes()  - [ ["OIdentity", ["ORole", "OUser"]]] - [ ["OShape",["OGeometryCollection","OLineString", "OMultiLineString", "OMultiPoint", "OMultiPolygon", "OPoint", "OPolygon", "ORectangle"]  ] ]
		end
	end


=begin
Returns an array with all names of the classes of the database. Uses a cached version if possible.
  
Parameters: system_classes: false|true, requery: false|true
=end

  def database_classes system_classes: nil, requery: false
    class_hierarchy system_classes: system_classes #requery: true
    all_classes = get_classes('name').map(&:values).sort.flatten
    all_user_classes =  all_classes - system_classes()

    all_user_classes.each{|x| ActiveOrient.database_classes[x] = "unset" unless ActiveOrient.database_classes.has_key?(x) }
    
    ActiveOrient.database_classes.keys  # return an array of database-classnames
  end

=begin
Service-Method for Model#OrientdbClass
=end

  def get_db_superclass name   #:nodoc:
    @actual_class_hash = get_classes( 'name', 'superClass') if @actual_class_hash.nil? 
   z= @actual_class_hash.find{|x,y|  x['name'] == name.to_s }
   z['superClass'] unless z.nil?
  end

=begin
preallocate classes reads any class from the  @classes-Array and allocates adequat Ruby-Objects
=end
	def preallocate_classes   from_model_dir= nil  # :nodoc:
		# always scan for E+V model-file and include
		[E,V].each{|y| y.require_model_file(from_model_dir) }

		ActiveOrient.database_classes.each do | db_name, the_class |
			allocate_class_in_ruby( db_name ) do |detected_class|
			keep_the_dataset =  true
			# keep the class if it is already noted in database_classes 
		 if	![E,V].include?(detected_class) &&
				!ActiveOrient.database_classes.key( detected_class) && 
				!detected_class.require_model_file(from_model_dir) &&
			  !ActiveOrient::Model.keep_models_without_file  
	
				logger.info{ "#{detected_class.name} -->  Class NOT allocated"}
				ActiveOrient.database_classes[ detected_class.ref_name ] = "no model file"
				keep_the_dataset = false 
			end
			keep_the_dataset # return_value
		end  # block
		end  # each iteration
	end	# def

end # module
