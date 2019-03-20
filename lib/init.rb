module ActiveOrient
  module Init

=begin
Parameters: 
 yml: hash from config.yml , 
 namespace: Class to use as Namespace

A custom Constant can be provided via Block

i.e.
  configyml =  YAML.load_file (...)  # with an entry "namespace:" 
  ActiveOrient.Init.define_namespace yml: configyml 
  #or
  ActiveOrient.Init.define_namespace namespace: :self | :object | :active_orient
  #or
  module IB # first declare the Module-Const
  end	    # then assign to the namespace
  ActiveOrient.Init.define_namespace { IB } 

	If a namespace is defined providing a block, 

			ActiveOrient::Model.keep_models_without_file 
	
	is set, thus enabling subsequent Namespaces

		
=end
    def self.define_namespace(  yml: {}, namespace: nil )
      n =  namespace.presence || yml[:namespace].presence || :object
			ActiveOrient::Model.namespace = if block_given?
																				ActiveOrient::Model.keep_models_without_file = true
																				yield
																			else
																				case n
																				when :self
																					ActiveOrient::Model
																				when :object
																					Object
																				when :active_orient
																					ActiveOrient
																				end
																			end
		end # define namespace
  end # module Init
end  # module ActiveOrient
