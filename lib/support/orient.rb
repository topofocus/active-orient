module OrientSupport

	# This Module fences specialized Ruby objects

	# The Array _knows_ its database-class. This enables database-transactions outside the scope
	# of ActiveOrient
	#
	# The Database-Class is available through Array#record


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
			@name = @orient.attributes.key(self) 
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
			@name =  yield if @name.nil? && block_given?
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
#		returns the modified array and is chainable
#
#      i= V.get( '89:0')
	#    ii=i.zwoebelkuchen <<  'z78' << 6 << [454, 787]
	#		 => [7, 5, 6, "z78", 78, 45, "z78", 6, 454, 787] 
=begin
Append the argument to the Array, changes the Array itself.

The change is immediately transmitted to the database. 


=end
		def   append arg
			
			@orient.update { "#{@name.to_s} = #{@name} || #{arg.to_or} "}[@name]
		end

		alias  << append 


		def remove *k
			# todo combine queries in a transaction
			ActiveOrient::Base.logger.debug { "delete: #{@name} --< #{k.map(&:to_or).join( ' :: ' )}"}
			k.map{|item| @orient.update( remove: true ){" #{@name} = #{item.to_or}"} }
			@orient.reload!
		end


=begin
	Updating of single items
=end

		def []= key, value
			super
			@orient.update set: {@name => self} if @name.present?
		end


		###
		## just works with Hashes as parameters
		def where *item
			where_string = item.map{|m| where_string = compose_where( m ) }.join(' and ')
			subquery= OrientSupport::OrientQuery.new from: @orient, projection: "expand( #{@name})"
			q= OrientSupport::OrientQuery.new from: subquery, where: item
			@orient.query q.to_s 

		end

		def method_missing *args
			if @orient.is_a? V

			end

			self.map{|x| x.send *args }
		rescue NoMethodError => e
			ActiveOrient::Base.logger.error("OrientSupport::Array"){ "MethodMissing  -> Undefined method: #{args.first} --  Args: #{args[1..-1].inspect}"}
			ActiveOrient::Base.logger.error {" The Message #{e.message}"}
			ActiveOrient::Base.logger.error{ e.backtrace.map {|l| "  #{l}\n"}.join  }
		end

	end #Class




	class Hash  < Hash # WithIndifferentAccess
		include OrientSupport::Support
		def initialize modelinstance, args
			super()
		#	puts "Hash.new args #{args}"
			@orient = modelinstance
			self.merge! args
			@name = modelinstance.attributes.key(self)
			@name =  yield if @name.nil? && block_given?
		#	puts "@name #{@name}"
			self
		end


		def store  k, v
			super
			 @orient.update{ "#{@name.to_s}.#{k.to_s} = #{v.to_or}" }[@name]
		end

		alias []= store

# Inserts the provided Hash to the (possibly empty) list-property and returns the modified hash	
		#
		# Keys are translated to symbols 
		#
		# Merge does not support assigning Hashes as values
		def merge **arg
			super
			updating_string =  arg.map{|x,y| "#{@name}.#{x} = #{y.to_orient}" unless y.is_a?(Hash) }.compact.join( ', ' )
			@orient.update( delete_cach: true ) { updating_string }[@name]
		end

		alias  << merge 

# removes a key-value entry from the hash. 
# 
# parameter: list of key's (duplicate values are removed)
#
# returns the removed items 
		def remove *k
			# todo combine queries in a transaction
			r= k.map{ |key| @orient.update( remove: true ) { "#{@name.to_s}.#{key} " } }.last
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

		def coerce arg
			if arg.is_a? DateTime
				nil
			else
				super

			end
		end
end
