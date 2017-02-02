module OrientSupport

# This Module fences specialized Ruby objects

  class Array < Array
    include OrientSupport::Support
    mattr_accessor :logger

=begin
  Initialisation method stores the model-instance to work on  in @orient.
  The keyword_parameter "work_on" holds the record to work_ion.
  Ihe second argument is the array to work with

  If instead of a model-instance the model-class is provided, a new model-instance is created and returned
  Its up to the caller to save the new instance in the database 

  Further a list of array-elements is expected, which are forwarded (as Array) to Array
=end

    def initialize work_on:, work_with: 
      @orient = work_on.class == Class ? work_on.new : work_on
      super work_with
      @name = @orient.attributes.key(self)
    #  puts "ORIENT: #{@orient.inspect} "
      @name =  yield if @name.nil? && block_given?
    #  puts "NAME: #{@name.inspect}"
    #  puts "SELF: #{self.inspect}"
    end

    def record
      @orient
    end
=begin
Append the argument to the Array, changes the Array itself.

The change is transmitted to the database immediately
=end
    def << *arg
      @orient.add_item_to_property(@name, *arg) if @name.present?
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

#    def [] *arg
#      #puts "ARG #{arg}"
#      super
#    end
#
=begin
Remove_at performs Array#delete_at
=end
    def remove_at *pos
      @orient.remove_position_from_property(@name,*pos) if @name.present?
    end

#
#    alias :del_org :delete 
=begin
Remove performs Array#delete 

If the Array-element is a link, this is removed, the linked table is untouched
=end
    def remove  *item
      @orient.remove_item_from_property(@name,*item) if @name.present?
    end
###
    ## just works with Hashes as parameters
    def where *item
      where_string = item.map{|m| where_string = compose_where( m ) }.join(' and ')
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
      
        map{|x| x.send *args }
      rescue NoMethodError => e
        logger.progname = "OrientSupport::Array#MethodMissing"
        logger.error{"Undefined method: #{e.message}"}
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
      # @name is the property of @orient to work on
      @name = modelinstance.attributes.key(self)
#      puts "ORIENT: #{@orient.inspect} "
      @name =  yield if @name.nil? && block_given?
#      puts "NAME: #{@name.inspect}"
#      puts "SELF: #{self.inspect}"
    end


    def []=  key, value
      puts " i will handle this in the future"
    #@orient.attributes[key] = value
	
#	r = (@orient.query  "update #{@orient.rid} put #{@name} = #{key.to_orient}, #{value.to_orient} RETURN AFTER @this").pop
	super key, value
	@orient.update set:{ @name => self}
#	@orient = @orient.class(@orient.rid){r} if r.is_a? ActiveOrient::Model
#	 self[ key ]= value
#	 puts self.inspect 
	#@orient[@name]=self.merge  key => value
	#
    end

    def delete key
      super key
      @orient.update set:{ @name => self}
    end

    def delete_if &b
      super &b
      @orient.update set:{ @name => self}

    end

#     self
#    end

  end
end #Module
