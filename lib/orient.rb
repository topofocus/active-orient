module OrientSupport
=begin 
This Module fences specialized ruby objects 
=end

  class Array < Array
=begin
Initialisation method stores the modelinstance in @orient.

Further a list of array-elements is expected, which are forwarded (as Array) to Array 


=end
    def initialize modelinstance, *args
      @orient =  modelinstance
      super args
      @name = modelinstance.attributes.key(self)

    end

    def << arg
       @orient.add_item_to_property @name,  arg 
    end

    def delete_at *pos
       delete self[*pos]      
       #       old version: works only if the hole array is loaded into memory
#       self[*pos]=nil
#      @orient.update set:{ @name => self.compact }
    end

    def delete_if
      delete *self.map{|y|  y if yield(y) }.compact  # if the block returns true then delete the item
    end

    def delete *item
      @orient.remove_item_from_property( @name ) {  item  }
    end

  end
  class LinkMap < OrientSupport::Array

    def []= arg
    end
  end 

end
