module OrientSupport
=begin
This Module fences specialized ruby objects
=end

  class Array < Array
    include OrientSupport::Support

    def initialize modelinstance, *args
      @orient =  modelinstance
      super args
      @name = modelinstance.attributes.key(self)
    end

    def << arg
      @orient.add_item_to_property(@name, arg ) if @name.present?
      super
    end

    def []= key, value
      super
      @orient.update set: {@name => self} if @name.present?
    end

    def [] *arg
      super
    end

    def delete_at *pos
      if @name.present?
        delete self[*pos]
      else
	      super
      end
    end

    def delete_if
      if @name.present?
        delete *self.map{|y| y if yield(y)}.compact  # if the block returns true then delete the item
      else
	      super
      end
    end

    def delete *item
      @orient.remove_item_from_property( @name ){item} if @name.present?
    end

    def where *item
      where_string = item.map{|m| where_string = compose_where m}.join(' and ')
      query = "select from ( select expand( #{@name} ) from #{@orient.classname})  #{where_string} "
      puts query
      @orient.query query
    end

    def method_missing *args
      map{|x| x.send args.first }
    end

  end #Class

  class LinkMap < OrientSupport::Array
    def []= arg
    end
  end  #Class

end #Module
