module OrientSupport

# This Module fences specialized Ruby objects

  class Array < Array
    include OrientSupport::Support
    mattr_accessor :logger

=begin
  Initialisation method stores the modelinstance in @orient.
  Further a list of array-elements is expected, which are forwarded (as Array) to Array
=end

    def initialize modelinstance, *args
      @orient = modelinstance
      super args
      @name = modelinstance.attributes.key(self)
    end

    def << arg
      #print "\n ---> #{@name}, #{arg} <--- \n"
      @orient.add_item_to_property(@name, arg) if @name.present?
      super
    end

=begin
  Updating of single items

  This only works if the hole embedded Array is previosly loaded into the Ruby-array.
=end

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
      print "TEST A \n"
      @orient.remove_item_from_property(@name){item} if @name.present?
    end

    ## just works with Hashes as parameters
    def where *item
      where_string = item.map{|m| where_string = compose_where m}.join(' and ')
       subquery= OrientSupport::OrientQuery.new from: @orient, projection: "expand( #{@name})"
       q= OrientSupport::OrientQuery.new from: subquery, where: item
#      query = "SELECT FROM ( SELECT EXPAND( #{@name} ) FROM #{@orient.classname})  #{where_string} "
     # puts q.compose
     #  sql_cmd = -> (command) {{ type: "cmd", language: "sql", command: command }}
    #  @orient.orientdb.execute do
#	  sql_cmd[query.to_s]
#      end
       @orient.query q 
    end

    def method_missing *args
      begin
        map{|x| x.send args.first}
      rescue NoMethodError => e
        logger.progname = "OrientSupport::Array#MethodMissing"
        logger.error{"Undefined method: #{e.message}"}
      end
    end

  end #Class

  class LinkMap < OrientSupport::Array
    def []= arg
    end
  end  #Class

end #Module
