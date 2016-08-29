module ActiveOrient
  module Init

    def define_namespace  namespace=nil
      ActiveOrient::Model.namespace = if namespace.nil? 
					if env == 'test'
					  Object
					else
					  n= configyml.present? ? configyml[:namespace] : :self
					  case n
					  when :self
					    ActiveOrient::Model
					  when :object
					    Object
					  when :active_orient
					    ActiveOrient
					  end
					end
				      else
					namespace

				      end
    end # define namespace

    def vertex_and_edge_class
      ORD.create_classes 'E', 'V'
      E.ref_name = 'E'
      V.ref_name = 'V'

    end
  end # module Init
end  # module ActiveOrient
