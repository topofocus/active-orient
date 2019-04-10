
## This is an init-script intented to be copied to 
## rails-root/config/initializers

## Integrate a namespaced model
#module HC
#
#end
#
#Hc = HC
#ActiveOrient::Model.keep_models_without_file = false
#ActiveOrient::Init.define_namespace { HC } 
#ActiveOrient::OrientDB.new  preallocate:  true
#
# class ActiveOrient::Model
#        def self.namespace_prefix
#	       ""
#        end
# end
#
# At the end: include everything which is not yet allocated to some namespaced model
ActiveOrient::Init.connect 
ActiveOrient::Model.keep_models_without_file = true

ActiveOrient::OrientDB.new  preallocate:  true







