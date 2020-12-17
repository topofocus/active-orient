module OrientSupport

	# This Module fences specialized Ruby objects

	# The Array _knows_ its database-class. This enables database-transactions outside the scope
	# of ActiveOrient
	#
	# The Database-Class is available through Array#record
#
# *caution:*
# Don't mix ActiveOrient::Array's with conventional ones
#   	> t= G21.first
#     > t.ll
#      => ["test", "test_2", 5, 8, 7988, "uzg"]
#   	> t.ll = [9,6,7]    # This is an assignment of an Array to the variable »ll»
#													# It does NOT call ActiveOrient::Array#=[]. 
#   	 => [9, 6, 7]       # Instead an Array is assigned to the variable  »ll»
#   
# it is only updated localy, as shown if we reload the document
#     > t= G21.first.attributes
#      => {:ll=>["test", "test_2", 5, 8, 7988, "uzg"]} 
#   
# Thus its imperativ to safe the changes made.
   
   
	class Array < Array
		include OrientSupport::Support

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
			begin
			@name =  block_given? ? yield : @orient.attributes.key(self)
			rescue TypeError => e   #  not defined
				ActiveOrient::Base.logger.debug{ "--------------------Type Error ----------------------------------" }
			ActiveOrient::Base.logger.debug("OrientSupport::Array"){ "Attributes  #{@orient.attributes.inspect}" }
			ActiveOrient::Base.logger.debug("OrientSupport::Array"){ e.inspect 
			ActiveOrient::Base.logger.debug{ "indicates a try to access a non existing array element" }}
			nil
			rescue NameError =>e
			ActiveOrient::Base.logger.debug{ "--------------------Name Error ------------" }
			ActiveOrient::Base.logger.debug ("OrientSupport::Array"){ e.inspect }
			#ActiveOrient::Base.logger.error{ e.backtrace.map {|l| "  #{l}\n"}.join  }
			ActiveOrient::Base.logger.debug{ "due to a bug in ActiveSupport DateTime Calculations" }
			# we just ignore the error
			end
		end
		def as_json o=nil
			map{|x| x.rid? ? x.rid : x }
		end

		def record
			@orient
		end

		def to_human
			map &:to_human 
		end
=begin

Appends the arguments to the Array.

Returns the modified database-document (not the array !!)
=end
		def   append *arg
			
			@orient.update { "set #{@name.to_s} = #{@name} || #{arg.to_or} "}[@name] if check_if_complete
			@orient.reload!
		end
=begin
Append the argument to the Array, changes the Array itself.

Returns the modified Array ( and is chainable )
#
#      i= V.get( '89:0')
	#    ii=i.zwoebelkuchen <<  'z78' << 6 << [454, 787]
	#		 => [7, 5, 6, "z78", 78, 45, "z78", 6, 454, 787] 

The change is immediately transmitted to the database. 

The difference to `append`: that method accepts a komma separated list of arguments
and returns the modified database-document. `<<` accepts only one argument. An 
Array  is translated into multi-arguments of `append`

	> t =  G21.create  ll:  ['test','test_2', 5, 8 , 7988, "uzg"]
	  INFO->CREATE VERTEX ml_g21 CONTENT {"ll":["test","test_2",5,8,7988,"uzg"]}
	  => #<ML::G21:0x0000000002622cb0 @metadata={:type=>"d", :class=>"ml_g21", :version=>1, 
	  :fieldTypes=>nil, :cluster=>271, :record=>0}, 
		@attributes={:ll=>["test", "test_2", 5, 8, 7988, "uzg"]}> 
 > t.ll << [9,10]
    INFO->update #271:0 set ll = ll || [9, 10]   return after @this
     => ["test", "test_2", 5, 8, 7988, "uzg"] 
 > t.ll << [9,10] << 'u'
    INFO->update #271:0 set ll = ll || [9, 10]   return after @this
    INFO->update #271:0 set ll = ll || ['u']   return after @this
 => ["test", "test_2", 5, 8, 7988, "uzg", 9, 10]


The Array can be treated separately

  > z =  t.ll
	 => ["test", "test_2", 5, 8, 7988, "uzg"] 
  > z << 78
  INFO->update #272:0 set ll = ll || [78]   return after @this
  => ["test", "test_2", 5, 8, 7988, "uzg", 78] 

=end
		def << arg
			append( *arg).send @name 
		end

=begin

Removes the specified list entries from the Array

Returns the modified Array  (and is chainable).

 > t= G21.first
 > t.ll
   => ["test", "test_2", 7988, "uzg", 6789, "xvy"] 
 > u=  t.ll << 'xvz'
 # INFO->update #272:0 set ll = ll || ['xvz']   return after @this
 => ["test", "test_2", 7988, "uzg", 6789, "xvy", "xvz"] 
 > z=  u.remove 'xvy'
 # INFO->update #272:0 remove  ll = 'xvy'  return after @this
 => ["test", "test_2", 7988, "uzg", 6789, "xvz"] 

The ModelInstance is updated, too, as shown by calling 

> t.ll
 => ["test", "test_2", 7988, "uzg", 6789, "xvz"] 


Thus 

 > t.ll.remove 7988
 # INFO->update #272:0 remove  ll = 7988  return after @this
 => ["test", "test_2", "uzg", 6789, "xvz"] 
 
returns thea modified Array 
=end
		def remove *k
			# todo combine queries in a transaction
			ActiveOrient::Base.logger.debug { "delete: #{@name} --< #{k.map(&:to_or).join( ' :: ' )}"}
		 k.map{|l|	@orient.update( {remove: { @name => l} } ) }
	#		@orient.reload!
	#		@orient.send @name 
		end

		def remove_by_index index
			@orient.update( { remove: { @name => "#{@name[index]}" } } )
		end

def check_if_complete
	if @name.blank?
		@orient.logger.warn{ "Database is uneffected. Operation is incomplete/ not allowed" }
		false
	else
		true
	end
end
=begin
	Updating of single items
=end
		def []= key, value
			super
			@orient.update set: {@name => self} if @name.present?  if check_if_complete
		end


		###
		## just works with Hashes as parameters
		def where *item
			where_string = item.map{|m| where_string = compose_where( m ) }.join(' and ')
			subquery= OrientSupport::OrientQuery.new from: @orient, projection: "expand( #{@name})"
			q= OrientSupport::OrientQuery.new from: subquery, where: item
			@orient.db.execute{  q.to_s } if check_if_complete

		end

		def method_missing method, *args
			return if empty?
			if @orient.is_a? ActiveOrient::Model  #  IB::Model
				# delegate to public methods
				self.map{|x| x.public_send(method, *args)}
			else
				self.map{|x| x.send method, *args }
			end
		rescue NoMethodError => e
			ActiveOrient::Base.logger.error("OrientSupport::Array"){ "#{self.inspect} MethodMissing  -> Undefined method: #{args.first} --  Args: #{args[1..-1].inspect}"}
			ActiveOrient::Base.logger.error {" The Message #{e.message}"}
			ActiveOrient::Base.logger.error{ e.backtrace.map {|l| "  #{l}\n"}.join  }
			raise
		end

	end #Class




	class Hash  < Hash # WithIndifferentAccess
		include OrientSupport::Support
		def initialize modelinstance, args
			super()
			@orient = modelinstance
			self.merge! args
			@name =  block_given? ? yield : modelinstance.attributes.key(self)
			self
		end


		def store  k, v
#			super
#			 @orient.update set:{ @name => {k => v} }# { "#{@name.to_s}.#{k.to_s} = #{v.to_or}" }[@name]
#			 @orient.send @name.to_sym
			@orient.update { "set #{@name.to_s}[#{k.to_s.to_or}] = #{v.to_or} "}[@name] #if check_if_complete
	#		@orient.reload!
		end

		alias []= store

# Inserts the provided Hash to the (possibly empty) list-property and returns the modified hash	
		#
		# Keys are translated to symbols 
		#
		# Merge does not support assigning Hashes as values
		# ** incomplete **
		def merge **arg
			self.to_h.merge arg
#			@orient.update @name => self.to_h.merge( arg ) 
#			arg.each{|a,b| self.store a,b}
		end

		alias  << merge 

# removes a key-value entry from the hash. 
# 
# parameter: list of key's 
#
# returns the modified OrientSupport::Hash 
		#
		# ie, given
		#  b =>  <Base[51:0]: < Base: 51:0 >, a_set : {:warrant_value=>["8789", "HKD"], :what_if_pm_enabled=>["true", ""], :t_bill_value=>["0", "HKD"]}>
		# c= b.a_set.remove :warrant_value
		# INFO->update #51:0  remove a_set = 'warrant_value'   return after $current
		# c =>  {:what_if_pm_enabled=>["true", ""], :t_bill_value=>["0", "HKD"]}


		def remove *k
			# todo combine queries in a transaction
				
			r=  k.map{|key|	@orient.update{   "remove #{@name} = #{key.to_s.to_or} "  } }
			@orient.reload!.send @name

		end
	#	def delete *key
#
#			key.each do | k |
#				o = OrientSupport::OrientQuery.new from: @orient, 
#																						kind: 'update', 
#																						set: "#{@name}.#{k.to_s}",
#																					return: "$current.#{@name}"
#			@orient.db.execute{  o.to_s.gsub( 'set ', 'remove ' ) }.first.send( @name )  # extracts the modified array (from DB)  from the result
#			end
#			@orient.reload!
#			@orient.send @name  # return value
#	end

		def delete_if &b
			super &b
			@orient.update set:{ @name => self}

		end

 # slice returns a subset of the hash 
		#
		# excepts a regular expression as well
		def slice arg
			if arg.is_a? Regexp
				find_all{ |key| key.to_s.match(arg) }.to_h
			else
				 super arg.to_sym
			end
		end
		def [] arg
			super
		end
	end
end #Module

class Hash

	  def to_human
			"{ " + self.map{ |k,v| [k.to_s,": ", v.to_orient].join }.join(', ') + " }"
		end

	#	def coerce arg
	#		if arg.is_a? DateTime
	#			nil
	#		else
	#			super
#
#			end
#		end
end
