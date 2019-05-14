=begin
Rails-specific stuff

Mimics ActiveModell::conversions
=end
module  Conversions


=begin
  Returns an Array of all key attributes if any is set, regardless if the object is persisted or not. Returns nil if there are no key attributes.
=end
   def to_key
           key = respond_to?(:rid) && rid
	         key ? [key] : nil
   end

 # Returns a +string+ representing the object's key suitable for use in URLs,
 #     # or +nil+ if <tt>persisted?</tt> is +false+.
  def to_param
          (persisted? && key = to_key) ? key.join('-') : nil
  end


 # Returns a +string+ identifying the path associated with the object.
 #     # ActionPack uses this to find a suitable partial to represent the object.
 def to_partial_path
         self.class._to_partial_path
 end

# module ClassMethods #:nodoc:
   # Provide a class level cache for #to_partial_path. This is an
   # internal method and should not be accessed directly.
   
#   def self._to_partial_path #:nodoc:
#     @_to_partial_path ||= begin
#	element = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(name))
#	collection = ActiveSupport::Inflector.tableize(name)
#	"#{collection}/#{element}".freeze
#      end
#   end
 #end
end
