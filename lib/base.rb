module REST
  require 'active_model'
  # Base class for tableless IB data Models, extends ActiveModel API
  class String
    def rid? 
      self =~  /[0-9]{1,}:[0-9]{1,}/
    end
  end
  class Base
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Serializers::Xml
    include ActiveModel::Serializers::JSON
    

    ##Every Rest::Base-Object is stored in the @@rid_store
    ## The Objects are just references to the @@rid_store.
    ## any Change of the Object is thus synchonized to any allocated variable
    #
    @@rid_store =  Hash.new
    def self.store_riid obj
      if obj.rid.present? && obj.riid.all?{|x| x.present? && x>=0} # only positive values are stored
	  ## return the presence of a stored object as true by the block
	  ## the block is only executed if the presence is confirmed
	  ##  Nothing is returned from the class-method
	if @@rid_store[obj.riid].present? 
	  yield  if block_given?  	    
	end
	 @@rid_store[obj.riid] = obj
	 @@rid_store[obj.riid]  # return_value
      else
	obj # no rid-value: just return the obj
      end
    end

    define_model_callbacks :initialize

    mattr_accessor :logger
    # If a opts hash is given, keys are taken as attribute names, values as data.
    # The model instance fields are then set automatically from the opts Hash.
    def initialize attributes={}, opts={}
      logger.progname= "REST::Base#initialize"
      possible_link_array_candidates = Hash.new
      @metadata = HashWithIndifferentAccess.new
      run_callbacks :initialize do
      attributes.keys.each do | att |
	unless att[0] == "@"	  
	  att =  att.to_sym if att.is_a?(String)    
	  unless self.class.instance_methods.detect{|x| x == att.to_sym }
	    self.class.define_property att, nil 
	    logger.debug { "property #{att.to_s} assigned to #{self.class.to_s}" }
	  end
	end
      end

      if attributes['@type'] == 'd'  # document 
	  possible_link_array_candidates = attributes.find_all{|_,v| v.is_a?(Hash) }.to_h
	  attributes.delete_if {|_,v| v.is_a?(Hash) }
	  link_candidates = attributes.find_all{|_,v| v.is_a?(String) && v.rid?}
	  @metadata[ :type    ] = attributes.delete '@type'
          @metadata[ :class   ] = attributes.delete '@class' 
          @metadata[ :version ] = attributes.delete '@version' 
          @metadata[ :fieldTypes ] = attributes.delete '@fieldTypes' 
	  if attributes.has_key?( '@rid' )
	    rid = attributes.delete '@rid' 
	    cluster, record = rid[1,rid.size].split(':') 
	    @metadata[ :cluster ] =  cluster.to_i
	    @metadata[ :record ] = record.to_i
	  end
      end
      
      if possible_link_array_candidates.present?
	logger.debug "possible link-array: #{possible_link_array_candidates.inspect}"
      end


      #
       # raise RuntimeError "Argument must be a Hash", :args unless attributes.is_a?(Hash)

        self.attributes = attributes # set_attribute_defaults is now after_init callback
      end
      REST::Base.store_riid self
    end

    # ActiveModel API (for serialization)

    def attributes
      @attributes ||= HashWithIndifferentAccess.new
    end

    def attributes= attrs
      attrs.keys.each { |key| self.send("#{key}=", attrs[key]) }
    end

    # ActiveModel-style read/write_attribute accessors
    def [] key
      attributes[key.to_sym]
    end

    def update_attribute key, value
      @attributes[key] = value
    end

    def []= key, val
      # p key, val
      attributes[key.to_sym] = val
    end

    def to_model
      self
    end

    def new_record?
      true
    end

    def save
      valid?
    end

    alias save! save

    ### Noop methods mocking ActiveRecord::Base macros
    
    def self.attr_protected *args
    end

    def self.attr_accessible *args
    end

    ### ActiveRecord::Base association API mocks

    def self.belongs_to model, *args
      attr_accessor model
    end

    def self.has_one model, *args
      attr_accessor model
    end

    def self.has_many models, *args
      attr_accessor models

      define_method(models) do
        self.instance_variable_get("@#{models}") ||
          self.instance_variable_set("@#{models}", [])
      end
    end

    def self.find *args
      []
    end

    ### ActiveRecord::Base callback API mocks

    define_model_callbacks :initialize, :only => :after

    ### ActiveRecord::Base misc

    def self.serialize *properties
    end

  end # Model
end # module 
