module OrientSupport

# This Module fences specialized Ruby objects

# The Array _knows_ its database-class. This enables database-transactions outside the scope
# of ActiveOrient
#
# The Database-Class is available through Array#record


  class Array < Array
    include OrientSupport::Support
    mattr_accessor :logger

=begin
  During initialisation  the model-instance to work on is stored  in @orient.
  
  The keyword_parameter »work_on« holds the record to work on.
  The second argument holds the array to work with

  If instead of a model-instance the model-class is provided, a new model-instance is created and returned
  Its up to the caller to save the new instance in the database 

  Further a list of array-elements is expected, which are forwarded (as Array) to Array

  Its used to initialize Objects comming from the database (i.e. /lib/base.rb)

     elsif iv.is_a? Array
           OrientSupport::Array.new( work_on: self, work_with: iv.from_orient){ key.to_sym }

=end

    def initialize( work_on:, work_with: )
      @orient = work_on.class == Class ? work_on.new : work_on
      super work_with
      @name = @orient.attributes.key(self)
      @name =  yield if @name.nil? && block_given?
    end
    def as_json
      map{|x| x.rid? ? x.rid : x }
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

=begin
Remove_at performs Array#delete_at
=end
    def remove_at *pos
      @orient.remove_position_from_property(@name,*pos) if @name.present?
    end

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
      @name = modelinstance.attributes.key(self)
      @name =  yield if @name.nil? && block_given?
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
  end
end #Module
