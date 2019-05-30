module  ActiveOrient


# Base class for tableless IB data Models, extends ActiveModel API

  class Base
#		include OrientSupport::Logging 
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks
    include ActiveModel::Validations
    include ActiveModel::Serialization
#    include ActiveModel::Serializers::Xml
    include ActiveModel::Serializers::JSON
    include OrientDB
    include Conversions   # mocking ActiveModel::Conversions

		mattr_accessor :logger 

    define_model_callbacks :initialize
# ActiveRecord::Base callback API mocks
    define_model_callbacks :initialize, :only => :after

# Used to read the metadata
    attr_reader :metadata

=begin
  Every Rest::Base-Object is stored in the @@rid_store
  The Objects are just references to the @@rid_store.
  Any Change of the Object is thus synchonized to any allocated variable.
=end
    @@rid_store = Hash.new
		@@mutex = Mutex.new

    def self.display_rid
      @@rid_store
    end

=begin
removes an Item from the cache

obj has to provide a method #rid 

thus a string or a Model-Object is accepted
=end

    def self.remove_rid obj
			if obj &.rid.present?
			@@mutex.synchronize do 
				@@rid_store.delete obj.rid     
			end
			else
				logger.error "Cache entry not removed: #{obj} "
			end
		end

    def self.get_rid rid
      rid =  rid[1..-1] if rid[0]=='#'
      @@rid_store[rid] 
    end

    def self.reset_rid_store
      @@rid_store = Hash.new
    end

=begin
Stores the obj in the cache.

If the cache-value exists, it is updated by the data provided in obj
and the cached obj is returned
  
=end
    def self.store_rid obj

			@@mutex.synchronize do 
				if obj.rid.present? && obj.rid.rid?
					if @@rid_store[obj.rid].present?
						@@rid_store[obj.rid].transfer_content from: obj
					else
						@@rid_store[obj.rid] =   obj
					end
					@@rid_store[obj.rid] 
				else
					nil 
				end
			end
		end


    # rails compatibility
    # remap rid to id unless id is present
#    def id
#      attributes[:id].present? ?  attributes[:id] : rrid
#    end


=begin
If a opts hash is given, keys are taken as attribute names, values as data.
The model instance fields are then set automatically from the opts Hash.
=end

		def initialize attributes = {}, opts = {}
			logger.progname = "ActiveOrient::Base#initialize"
			@metadata = Hash.new # HashWithIndifferentAccess.new
			@d =  nil
			run_callbacks :initialize do
				if RUBY_PLATFORM == 'java' && attributes.is_a?( Document )
					@d = attributes
					attributes =  @d.values
					@metadata[:class]      = @d.class_name
					@metadata[:version]    = @d.version
					@metadata[:cluster], @metadata[:record] = @d.rid[1,@d.rid.size].split(':')
					puts "Metadata:  #{@metadata}"
				end

				# transform $current to :current and $current.mgr to :mgr
				 transformers = attributes.keys.map{|x|  [x, x[1..-1].split(".").last.to_sym] if x[0] == '$'}.compact
				 # transformers:  [ [original key, modified key] , [] ]
				 transformers.each do |a|
					 attributes[a.last] = attributes[a.first]
					 attributes.delete a.first
				 end

				attributes.keys.each do |att|
					unless att[0] == "@" # @ identifies Metadata-attributes
						unless self.class.instance_methods.detect{|x| x == att.to_sym}
							self.class.define_property att.to_sym, nil
						else
							#logger.info{"Property #{att.to_s} NOT assigned"}
						end
					end
				end
				if attributes['@type'] == 'd'  # document via REST
					@metadata[:type]       = attributes.delete '@type'
					@metadata[:class]      = attributes.delete '@class'
					@metadata[:version]    = attributes.delete '@version'
					@metadata[:fieldTypes] = attributes.delete '@fieldTypes'
					
					if attributes.has_key?('@rid')
						rid = attributes.delete '@rid'
						cluster, record = rid[1 .. -1].split(':')
						@metadata[:cluster] = cluster.to_i
						@metadata[:record]  = record.to_i
					end

					if @metadata[:fieldTypes ].present? && (@metadata[:fieldTypes] =~ /=g/)
						@metadata[:edges] = { :in => [], :out => [] }
						edges = @metadata[:fieldTypes].split(',').find_all{|x| x=~/=g/}.map{|x| x.split('=').first}
						#  puts "Detected EDGES: #{edges.inspect}"
						edges.each do |edge|
							operator, *base_edge = edge.split('_')
							base_edge = base_edge.join('_')
							@metadata[:edges][operator.to_sym] << base_edge
						end
						#    unless self.class.instance_methods.detect{|x| x == base_edge}
						#      ## define two methods: out_{Edge}/in_{Edge} -> edge.
						#      self.class.define_property base_edge, nil
						#      allocate_edge_method = -> (edge)  do
						#        unless (ee=db.get_db_superclass(edge)) == "E"
						#          allocate_edge_method[ee]
						#          self.class.send :alias_method, base_edge.underscore, edge
						#      ## define inherented classes, tooa
						#      

						#    end
						#  end
					end
				end
				self.attributes = attributes # set_attribute_defaults is now after_init callback
			end
			#      puts "Storing #{self.rid} to rid-store"
			#      ActiveOrient::Base.store_rid( self ) do | cache_obj|
			#	 cache_obj.reload! self
			#      end
		end

# ActiveModel API (for serialization)

    def included_links
      meta= Hash[ @metadata[:fieldTypes].split(',').map{|x| x.split '='} ]
      meta.map{|x,y| x if y=='x'}.compact
    end

    def attributes
      @attributes ||= Hash.new # WithIndifferentAccess.new
    end

    def attributes= attrs
      attrs.keys.each{|key| self.send("#{key}=", attrs[key])}
    end

		def my_metadata key: nil, symbol: nil
			if @metadata[:fieldTypes].present?  
				meta= Hash[ @metadata[:fieldTypes].split(',').map{|x| x.split '='} ]
				if key.present?
					meta[key.to_s]
				elsif symbol.present?
					meta.map{|x,y| x if y == symbol.to_s }.compact
				else
					meta
				end
			end
		end

=begin
  ActiveModel-style read/write_attribute accessors

  Autoload mechanism and data conversion are defined in the method "from_orient" of each class
=end

		def [] key

			iv = attributes[key]
			if my_metadata( key: key) == "t"
				iv =~ /00:00:00/ ? Date.parse(iv) : DateTime.parse(iv)
			elsif my_metadata( key: key) == "x"
				iv = ActiveOrient::Model.autoload_object iv
			elsif iv.is_a? Array
				OrientSupport::Array.new( work_on: self, work_with: iv.from_orient){ key.to_sym }
			elsif iv.is_a? Hash
#				if iv.keys.include?("@class" )
#				ActiveOrient::Model.orientdb_class( name: iv["@class"] ).new iv
#				else
#					iv
				OrientSupport::Hash.new( self, iv.from_orient){ key.to_sym }
	#			end
				#     elsif iv.is_a? RecordMap 
				#      iv
				#       puts "RecordSet detected"
			else
				iv.from_orient
			end
		end

		def []= key, val
			val = val.rid if val.is_a?( ActiveOrient::Model ) && val.rid.rid?
			attributes[key.to_sym] = case val
															 when Array
																 if val.first.is_a?(Hash)
																	 v = val.map{ |x| x }
																	 OrientSupport::Array.new(work_on: self, work_with: v )
																 else
																	 OrientSupport::Array.new(work_on: self, work_with: val )
																 end
															 when Hash
																 if val.keys.include?("@class" )
																	 OrientSupport::Array.new( work_on: self, work_with: val.from_orient){ key.to_sym }
																 else
																	 OrientSupport::Hash.new( self, val  )
																 end
															 else
																 val
															 end
		end

    def update_attribute key, value
      @attributes[key] = value
    end

    def to_model   # :nodoc:
      self
    end

# Noop methods mocking ActiveRecord::Base macros

    def self.attr_protected *args
    end

    def self.attr_accessible *args
    end

# ActiveRecord::Base association API mocks
#
    def self.belongs_to model, *args # :nodoc:
      attr_accessor model
    end
#
    def self.has_one model, *args   # :nodoc:
      attr_accessor model
    end
#
    def self.has_many models, *args  # :nodoc:
      attr_accessor models
      define_method(models) do
        self.instance_variable_get("@#{models}") || self.instance_variable_set("@#{models}", [])
      end
    end
#
#    def self.find *args
#      []
#    end
#
=begin
Exclude some properties from loading via get, reload!, get_document, get_record
=end
    def self.exclude_the_following_properties *args
      puts "excluding #{args}"
    @excluded =  (@excluded.is_a?( Array))?  @excluded + args : args
      puts "#{self.inspect} --> excluded #{@excluded}"
    end

# ActiveRecord::Base misc
    def self.serialize *properties # :nodoc:
    end
# Enable lazy loading
    ActiveSupport.run_load_hooks(:active_orient, self)
  end # Model
end # module
