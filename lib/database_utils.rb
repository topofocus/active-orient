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
        if abstract
	  basic
	else
	  basic + extended
	end
    end
=begin
Returns the class_hierachy

To fetch all Vertices:
   class_hiearchie(base_class: 'V').flatten
To fetch all Edges:
   class_hierachy(base_class: 'E').flatten
--
notice: 
To retrieve the class hierarchy from Objects avoid calling `ORD.classname (obj)`,  because it depends on class_hierarchy.
=end

  def class_hierarchy base_class: '',  system_classes: nil
    @actual_class_hash = get_classes('name', 'superClass') #if requery || @all_classes.blank?
    def fv s   # :nodoc:
  	@actual_class_hash.find_all{|x| x['superClass']== s}.map{|v| v['name']}
    end

    def fx v # :nodoc:
  	  fv(v.strip).map{|x| ar = fx(x); ar.empty? ? x : [x, ar]}
    end
    if system_classes.present?
	 fx base_class.to_s
    else
    	 fx( base_class.to_s ) - system_classes()  - [ ["OIdentity", ["ORole", "OUser"]]]
    end
  end


=begin
Returns an array with all names of the classes of the database. Uses a cached version if possible.
  
Parameters: system_classes: false|true, requery: false|true
=end

  def database_classes system_classes: nil, requery: false
    requery = true if ActiveOrient.database_classes.blank?
    if requery
  	  class_hierarchy system_classes: system_classes #requery: true
  	  all_classes = get_classes('name').map(&:values).sort.flatten
  	  ActiveOrient.database_classes = system_classes.present? ? all_classes : all_classes - system_classes()
    end
    ActiveOrient.database_classes
  end
=begin
Creates one or more vertex-classes and allocates the provided properties to each class.

  ORD.create_vertex_class :a
  => A
  ORD.create_vertex_class :a, :b, :c
  => [A, B, C]
=end

  def create_vertex_class *name, properties: nil 
    r= name.map{|n| create_class( n, properties: properties){ :V } }
    @actual_class_hash = get_classes( 'name', 'superClass')
 r.size == 1 ? r.pop : r
  end
=begin
Creates one or more edge-classes and allocates the provided properties to each class.
=end

  def create_edge_class *name,  properties: nil
    r = name.map{|n| create_class( n, properties: properties){ :E  } }
    @actual_class_hash = get_classes( 'name', 'superClass')
    r.size == 1 ? r.pop : r  # returns the created classes as array if multible classes are provided
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
 def preallocate_classes from_model_dir= nil  # :nodoc:
   #  first fetch all non-system-classes
#    io = class_hierarchy 
  # allocate them and call require_model_file on each model
    # if something goes wrong, allocate_classes_in_ruby returns nil, thus compact prevents
    # from calling NilClass.require_model_file
    all_classes = allocate_classes_in_ruby(class_hierarchy).flatten.compact
    classes_with_model_files = all_classes.map do |x| 
      success = x.require_model_file(from_model_dir) 
      if ActiveOrient::Model.keep_models_without_file.nil? && success.nil? && ![E,V].include?(x)
	logger.info{ "Database-Class #{x.name} is not asseccible, model file is missing "}
       x.delete_class :only_ruby_space
      end
      success # return_value
    end

 end

end # module
