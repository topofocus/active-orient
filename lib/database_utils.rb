module DatabaseUtils
=begin
returns the classes set by OrientDB
Parameter: abstract: true|false
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

  To fetch all Vertices uses:
   get_class_hiearchie(base_class: 'V').flatten
  To fetch all Edges uses:
   get_class_hierachy(base_class: 'E').flatten

  Notice: base_class has to be noted as String! There is no implicit conversion from Symbol or Class
  To retrieve the class hierarchy from Objects avoid calling classname,  because it depends on class_hierarchy.
=end

  def get_class_hierarchy base_class: '', requery: false
    @all_classes = get_classes('name', 'superClass') #if requery || @all_classes.blank?
    def fv s   # :nodoc:
  	@all_classes.find_all{|x| x['superClass']== s}.map{|v| v['name']}
    end

    def fx v # :nodoc:
  	  fv(v.strip).map{|x| ar = fx(x); ar.empty? ? x : [x, ar]}
    end
    fx base_class
  end
  alias class_hierarchy get_class_hierarchy

=begin
  Returns an array with all names of the classes of the database
  caches the result.
  Parameters: include_system_classes: false|true, requery: false|true
=end

  def get_database_classes include_system_classes: false, requery: false
    requery = true if ActiveOrient.database_classes.blank?
    if requery
  	  get_class_hierarchy requery: true
  	  all_classes = get_classes('name').map(&:values).flatten
  	  ActiveOrient.database_classes = include_system_classes ? all_classes : all_classes - system_classes
    end
    ActiveOrient.database_classes
  end
  alias inspect_classes get_database_classes
  alias database_classes get_database_classes

# Used for the connection on the server
    #
    def initialize_class_hierarchy
        logger.progname = 'OrientDB#InitializeClassHierachy'
      abstract_names, nested_classes = get_class_hierarchy.partition{|x| x if x.is_a? String}
      # concentrate all abstract classes in abstract_classes
      abstract_classes = (abstract_names - system_classes(abstract: true)).map do | abstract_class_name |
	 ActiveOrient::Model.orientdb_class name: abstract_class_name
      end
      other_classes =  initialize_classes( nested_classes )
      (abstract_classes + other_classes)

    end

    def initialize_classes array
      super_class =  block_given? ? yield : nil
      basic, complex = array.partition{|x| x.is_a? String } 
      basic_classes = (basic - system_classes).map do | base_class |
	 ActiveOrient::Model.orientdb_class name: base_class , superclass: super_class
      end
      nested_classes = (Hash[ complex ].keys - system_classes).map do | base_class |
	keyclass= ActiveOrient::Model.orientdb_class name: base_class , superclass: super_class
	dependend_classes = Hash[ array ][ base_class ]
	[keyclass, if dependend_classes.is_a? Array
	  initialize_classes( dependend_classes ){ base_class }
	else
	 ActiveOrient::Model.orientdb_class name: dependend_classes , superclass: base_class
	end
	]
      end
      [basic_classes, nested_classes ].compact
    end
  def create_vertex_class *name, properties: nil 
    create_class( :V ) unless database_classes.include? "V"
    r= name.map{|n| create_class( n, properties: properties){ :V } }
    @actual_class_hash = get_classes( 'name', 'superClass')
 r.size == 1 ? r.pop : r
  end

  def create_edge_class *name,  properties: nil
    create_class( :E ) unless database_classes.include? "E"
    r = name.map{|n| create_class( n, properties: properties){ :E  } }
    @actual_class_hash = get_classes( 'name', 'superClass')
    r.size == 1 ? r.pop : r  # returns the created classes as array
  end

  def get_db_superclass name
    @actual_class_hash.find{|x,y|  x['name'] == name.to_s }['superClass']
  end

=begin
preallocate classes reads any class from the  @classes-Array and allocates adequat Ruby-Objects
=end
 def preallocate_classes

   @actual_class_hash = get_classes( 'name', 'superClass')
   @actual_class_hash.each do | name_and_superclass |
     if database_classes.include? name_and_superclass['name']
       if name_and_superclass['superClass'].blank?
	 allocate_classes_in_ruby name_and_superclass['name']
       else
	 allocate_classes_in_ruby( {name_and_superclass["superClass"] => name_and_superclass['name'] } )
       end
     end 
   end
 end
end # module
