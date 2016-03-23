module  ActiveOrient
  require 'active_model'

  class Base
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Serializers::Xml
    include ActiveModel::Serializers::JSON

    define_model_callbacks :initialize
    define_model_callbacks :initialize, :only => :after
    mattr_accessor :logger
    attr_reader :metadata

    @@rid_store = Hash.new

    def self.display_rid
      @@rid_store
    end

    def self.remove_rid obj
      @@rid_store[obj.rid] = nil
    end

    def self.get_rid rid
    end

    def self.store_rid obj
      if obj.rid.present? && obj.rid.split(":").all?{|x| x.present? && x.to_i >=  0}
    # only positive values are stored
	  ## return the presence of a stored object as true by the block
	  ## the block is only executed if the presence is confirmed
	  ## Nothing is returned from the class-method
	      if @@rid_store[obj.rid].present?
	        yield if block_given?
	      end
	      @@rid_store[obj.rid] = obj
	      @@rid_store[obj.rid]  # return_value
      else
	      obj # no rid-value: just return the obj
      end
    end

    def initialize attributes = {}, opts = {}
      logger.progname = "ActiveOrient::Base#initialize"
      @metadata = HashWithIndifferentAccess.new
      run_callbacks :initialize do
        attributes.keys.each do |att|
	        unless att[0] == "@" # @ identifies Metadata-attributes
	          att = att.to_sym if att.is_a?(String)
	          unless self.class.instance_methods.detect{|x| x == att}
	            self.class.define_property att, nil
	          else
              #logger.info{"Property #{att.to_s} NOT assigned"}
	          end
	        end
	      end

        if attributes['@type'] == 'd'  # document
	        @metadata[:type]       = attributes.delete '@type'
	        @metadata[:class]      = attributes.delete '@class'
	        @metadata[:version]    = attributes.delete '@version'
	        @metadata[:fieldTypes] = attributes.delete '@fieldTypes'
	        if attributes.has_key?('@rid')
	          rid = attributes.delete '@rid'
	          cluster, record = rid[1,rid.size].split(':')
	          @metadata[:cluster] = cluster.to_i
	          @metadata[:record]  = record.to_i
	        end

          if @metadata[:fieldTypes ].present? && (@metadata[:fieldTypes] =~ /=g/)
	          edges = @metadata['fieldTypes'].split(',').find_all{|x| x=~/=g/}.map{|x| x.split('=').first}
	          edges.each do |edge|
	            operator, *base_edge = edge.split('_')
	            base_edge = base_edge.join('_')
	            unless self.class.instance_methods.detect{|x| x == base_edge}
                self.class.define_property base_edge, nil
                self.class.send :alias_method, base_edge.underscore, edge
              end
	          end
	        end
	      end
	      self.attributes = attributes # set_attribute_defaults is now after_init callback
	    end

      ActiveOrient::Base.store_rid self
    end

    def attributes
      @attributes ||= HashWithIndifferentAccess.new
    end

    def attributes= attrs
      attrs.keys.each{|key| self.send("#{key}=", attrs[key])}
    end

    def [] key
      iv = attributes[key.to_sym]
      if iv.is_a?(String) && iv.rid?
	      ActiveOrient::Model.autoload_object iv
      elsif iv.is_a?(Array)
	      OrientSupport::Array.new self, *iv.map{|y| (y.is_a?(String) && y.rid?) ? ActiveOrient::Model.autoload_object(y) : y}
      else
        if @metadata[:fieldTypes].present? && @metadata[:fieldTypes].include?(key.to_s+"=t")
	        iv =~ /00:00:00/ ? Date.parse(iv) : DateTime.parse(iv)
	      else
	        iv
	      end
      end
    end

    def []= key, val
      val = val.rid if val.is_a? ActiveOrient::Model
      attributes[key.to_sym] = case val
	    when Array
	      if val.first.is_a?(Hash)
	        v = val.map do |x|
	          if x.is_a?(Hash)
              HashWithIndifferentAccess.new(x)
	          else
		          x
	          end
	        end
	        OrientSupport::Array.new(self, *v )
	      else
	        OrientSupport::Array.new(self, *val )
	      end
	    when Hash
	      HashWithIndifferentAccess.new(val)
	    else
	      val
	    end
    end

    def update_attribute key, value
      @attributes[key] = value
    end

    def to_model
      self
    end

    def self.attr_protected *args
    end

    def self.attr_accessible *args
    end

    def self.belongs_to model, *args
      attr_accessor model
    end

    def self.has_one model, *args
      attr_accessor model
    end

    def self.has_many models, *args
      attr_accessor models
      define_method(models) do
        self.instance_variable_get("@#{models}") || self.instance_variable_set("@#{models}", [])
      end
    end

    def self.find *args
      []
    end

    def self.serialize *properties
    end

  end # Model
end # module
