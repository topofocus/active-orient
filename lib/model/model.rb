require_relative "the_class.rb"
require_relative "the_record.rb"
require_relative "custom.rb"
module ActiveOrient
  class Model < ActiveOrient::Base

    include BaseProperties
    include ModelRecord # For objects (file: lib/record.rb)
    extend CustomClass # for customized class-methods aka like
    extend ModelClass # For classes

=begin
Either retrieves the object from the rid_store or loads it from the DB.

Example:
  ActiveOrient::Model.autoload_object "#00:00"


The rid_store is updated!

_Todo:_ fetch for version in the db and load the object  only if a change is detected

_Note:_ This function is not located in ModelClass since it needs to use @@rid_store
=end

		def self.autoload_object rid
			rid = rid[1..-1] if rid[0]=='#'
			if rid.rid?
				if  @@rid_store[rid].present?
					@@rid_store[rid]  # return_value
				else
					get(rid)
				end
			else
				logger.progname = "ActiveOrient::Model#AutoloadObject"
				logger.info{"#{rid} is not a valid rid."}
			end
		end

    ## used for active-model-compatibility
    def persisted?
      true
    end



=begin
Based on the parameter rid (as "#{a}:{b}" or "{a}:{b}") the cached value is used if found.
Otherwise the provided Block is executed, which is responsible for the allocation of a new dataset

i.e.
  ActiveOrient::Model.use_or_allocated my_rid do
      ActiveOrient::Model.orientdb_class(name: raw_data['@class']).new raw_data
  end

=end
  
		def self.use_or_allocate rid
			cached_obj =  get_rid( rid ) 
			if cached_obj.present? 
				cached_obj
			else
				yield
			end
		end


   def self._to_partial_path #:nodoc:
     @_to_partial_path ||= begin
	element = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(name))
	collection = ActiveSupport::Inflector.tableize(name)
	"#{collection}/#{element}".freeze
      end
   end
    ## to prevent errors when calling to_a 
    def to_ary   # :nodoc:
      attributes.to_a
    end

    def document  # :nodoc:
      @d
    end

=begin
Deletes the database class and removes the ruby-class 
=end
		def self.delete_class what= :all
			orientdb.delete_class(  self ) if what == :all  # remove the database-class
			## namespace is defined in config/boot
			ns =  namespace.to_s == 'Object' ? "" : namespace.to_s
			ns_found = -> ( a_class ) do
				to_compare = a_class.to_s.split(':')
				if ns == "" && to_compare.size == 1 
					true
				elsif to_compare.first == ns
					true
				else
					false
				end
			end
			self.allocated_classes.delete_if{|x,y| x == self.ref_name && ns_found[y]}  if allocated_classes.is_a?(Hash)
			namespace.send(:remove_const, naming_convention.to_sym) if namespace &.send( :const_defined?, naming_convention)
		end

    # provides an unique accessor on the Class
    # works with a class-variable, its unique through all Subclasses
    mattr_accessor :orientdb  # points to the instance of the REST-DB-Client used for Administration
			      # i.e. creation and deleting of classes and databases
    mattr_accessor :db	      # points to the instance of the Client used for Database-Queries
    mattr_accessor :api
#    mattr_accessor :logger  ... already inherented from ::Base
    mattr_accessor :namespace # Namespace in which  Model records are initialized, a constant ( defined in config.yml )
    mattr_accessor :model_dir # path to model-files
    mattr_accessor :keep_models_without_file  
    mattr_accessor :allocated_classes

#    mattr_accessor  :ref_name    
    # Used to read the metadata
    attr_reader :metadata

    # provides an accessor at class level 
    # (unique on all instances)
      class << self
	    attr_accessor :ref_name
	    attr_accessor :abstract

			def to_or
				ref_name.to_or
			end


      end
  end
end
