module ActiveOrient
  module Init

=begin
Parameters: yml: hash from config.yml , namespace: Class to use as Namespace
A custom Constant can be provided via Block

i.e.
  configyml =  YAML.load_file (...)  # with an entry "namespace:" 
  ActiveOrient.Init.define_namespace yml: configyml 
  #or
  ActiveOrient.Init.define_namespace namespace: :self | :object | :active_orient
  #or
  ActiveOrient.Init.define_namespace { IB }  
=end
    def self.define_namespace  yml: {}, namespace: nil
      n =  namespace.presence || yml[:namespace].presence || :object
      ActiveOrient::Model.namespace = if block_given?
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
      ## initialitze Edge and Vertex classes in the namespace
      #      ActiveOrient::Model.orientdb_class( name:"E", superclass: "").new
      #      ActiveOrient::Model.orientdb_class( name:"V", superclass: "").new
    end # define namespace


    def vertex_and_edge_class
      ORD.create_classes 'E', 'V'
      E.ref_name = 'E'
      V.ref_name = 'V'

    end
  end # module Init
end  # module ActiveOrient
