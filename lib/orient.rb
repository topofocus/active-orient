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
    #  puts "ORIENT: #{@orient.inspect} "
      @name =  yield if @name.nil? && block_given?
    #  puts "NAME: #{@name.inspect}"
    #  puts "SELF: #{self.inspect}"
    end
=begin
Append the argument to the Array, changes the Array itself.

The change is transmitted to the database immediately
=end
    def << arg
#      print "\n <<---> #{@name}, #{arg} <--- \n"
      if @name.present?
	@orient.add_item_to_property(@name, arg)
      end
      super
    end

=begin
  Updating of single items

  This only works if the hole embedded Array is previously loaded into the Ruby-array.
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




  class Hash  < HashWithIndifferentAccess
    include OrientSupport::Support
    def initialize modelinstance, args
      @orient = modelinstance
      super args.from_orient
      @name = modelinstance.attributes.key(self)
#      puts "ORIENT: #{@orient.inspect} "
      @name =  yield if @name.nil? && block_given?
#      puts "NAME: #{@name.inspect}"
#      puts "SELF: #{self.inspect}"
    end


    def []=  key, value
      puts " i will handle this in the future"
    #@orient.attributes[key] = value
	r = (@orient.query  "update #{@orient.rid} put #{@name} = #{key.to_orient}, #{value.to_orient} RETURN AFTER @this").pop
	super key, value
#	@orient = @orient.class(@orient.rid){r} if r.is_a? ActiveOrient::Model
#	 self[ key ]= value
#	 puts self.inspect 
	#@orient[@name]=self.merge  key => value
	#
    end

    def to_orient
     self
    end

  end
end #Module
