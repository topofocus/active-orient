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
      super
       @orient.add_item_to_property( @name,  arg ) if @name.present?
    end

=begin
Updating of single items

this only works if the hole embedded Array is previosly loaded into the ruby-array. 
=end
    
    def []= key, value
      super
      @orient.update set: {  @name => self } if @name.present?
    end

    def [] *arg
    #  puts "[] ARG: #{arg.inspect}"
    #  arg.each{|u| puts "[] #{u.inspect} : #{u.class} " }
      super

    end

    def delete_at *pos
      if @name.present? 
       delete self[*pos]
      else
	super
      end
       #       old version: works only if the hole array is loaded into memory
#       self[*pos]=nil
#      @orient.update set:{ @name => self.compact }
    end

    def delete_if
      if @name.present?
      delete *self.map{|y|  y if yield(y) }.compact  # if the block returns true then delete the item
      else
	super
      end
    end

    def delete *item
      @orient.remove_item_from_property( @name ) {  item  } if @name.present?
    end

  end
  class LinkMap < OrientSupport::Array

    def []= arg
    end
  end 

end
