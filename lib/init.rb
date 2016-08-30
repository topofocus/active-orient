module ActiveOrient
  module Init

=begin
Parameters: yml: hash from config.yml , namespace: Class to use as Namespace

=end
    def define_namespace  yml: {}, namespace: nil
      ActiveOrient::Model.namespace = if namespace.present? 
					namespace
				      else
					n= yml[:namespace].presence || :self
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

    def vertex_and_edge_class
      ORD.create_classes 'E', 'V'
      E.ref_name = 'E'
      V.ref_name = 'V'

    end
  end # module Init
end  # module ActiveOrient
