require 'active_support/inflector'

module OrientSupport
  module Support

=begin
supports
  where: 'string'
  where: { property: 'value', property: value, ... }
  where: ['string, { property: value, ... }, ... ]

Used by update and select

_Usecase:_
 ORD.compose_where 'z=34', {u:6}
  => "where z=34 and u = 6" 
=end

    #
		def compose_where *arg , &b
			arg = arg.flatten.compact

			unless arg.blank? 
				g= generate_sql_list( arg , &b)
				"where #{g}" unless g.empty?
			end
    end

=begin
designs a list of "Key =  Value" pairs combined by "and" or the binding  provided by the block
   ORD.generate_sql_list  where: 25 , upper: '65' 
    => "where = 25 and upper = '65'"
   ORD.generate_sql_list(  con_id: 25 , symbol: :G) { ',' } 
    => "con_id = 25 , symbol = 'G'"

If »NULL« should be addressed, { key: nil } is translated to "key = NULL"  (used by set:  in update and upsert),
{ key: [nil]  } is translated to "key is NULL" ( used by where )

=end
		def generate_sql_list attributes = {},  &b
			fill = block_given? ? yield : 'and'
			case attributes 
			when ::Hash
				attributes.map do |key, value|
					case value
					when nil
						"#{key} =  NULL"
					when ::Array
						if value == [nil]
						"#{key} is NULL"
						else	
						"#{key} in #{value.to_orient}"
						end
					when Range
						"#{key} between #{value.first} and #{value.last} " 
					else #  String, Symbol, Time, Trueclass, Falseclass ...
						"#{key} = #{value.to_or}"
					end
				end.join(" #{fill} ")
			when ::Array
				attributes.map{|y| generate_sql_list y, &b }.join( " #{fill} " )
			when String
				attributes
			when Symbol, Numeric
				attributes.to_s
			end		
		end


    # used both in OrientQuery and MatchConnect
		# while and where depend on @q, a struct
		def while_s  value=nil     # :nodoc:
			if value.present?
				@q[:while] << value
				self
			elsif @q[:while].present?
				"while #{ generate_sql_list( @q[:while] ) }"
			end
		end
		def where  value=nil     # :nodoc:
			if value.present?
				if value.is_a?( Hash ) && value.size >1
												value.each {| a,b| where( {a => b} ) }
				else
					@q[:where] <<  value
				end
				self
			elsif @q[:where].present?
				"where #{ generate_sql_list( @q[:where] ){ @fill || 'and' } }"
			end
		end

		def as a=nil
			if a
				@q[:as] = a   # subsequent calls overwrite older entries
			else
				if @q[:as].blank?
					nil
				else
					"as: #{ @q[:as] }"
				end
			end
		end
	end  # module 

	######################## MatchConnection ###############################

	MatchAttributes = Struct.new(:edge, :direction, :as, :count, :where, :while, :max_depth , :depth_alias, :path_alias, :optional )

	# where and while can be composed incremental
	# direction, as, connect and edge cannot be changed after initialisation
  class MatchConnection
    include Support

    def initialize edge= nil, direction: :both, as: nil, count: 1, **args

      the_edge = edge.is_a?( Class ) ?  edge.ref_name : edge.to_s   unless edge.nil? || edge == E
			@q =  MatchAttributes.new  the_edge ,  # class
								direction, #		  may be :both, :in, :out
								as,				 #      a string
								count,     #      a number 
								args[:where],
								args[:while],
								args[:max_depth],
								args[:depth_alias],      # not implemented
								args[:path_alias],       # not implemented
								args[:optional]          # not implemented
    end

    def direction= dir
      @q[:direction] =  dir
    end


		def direction
			fillup =  @q[:edge].present? ? @q[:edge] : ''
			case @q[:direction]
			when :both
				".both(#{fillup})"
			when :in
				".in(#{fillup})"
			when :out
				".out(#{fillup})"
      when :both_vertex, :bothV
				".bothV()"
			when :out_vertex, :outV
				".outV()"
			when :in_vertex, :inV
				".inV()"
     when :both_edge, :bothE
			 ".bothE(#{fillup})"
			when :out_edge, :outE
				".outE(#{fillup})"
			when :in_edge, :outE
				".inE(#{fillup})"
			end

		end

		def count c=nil
			if c
				@q[:count] = c
			else
				@q[:count]
			end
		end

		def max_depth d=nil
			if d.nil?
				@q[:max_depth].present? ? "maxDepth: #{@q[:max_depth] }" : nil
			else
				@q[:max_depth] = d
			end
		end
		def edge
			@q[:edge]
		end

		def compose
				where_statement =( where.nil? || where.size <5 ) ? nil : "where: ( #{ generate_sql_list( @q[:where] ) })"
				while_statement =( while_s.nil? || while_s.size <5) ? nil : "while: ( #{ generate_sql_list( @q[:while] )})"
				
				ministatement = "{"+ [ as, where_statement, while_statement, max_depth].compact.join(', ') + "}"
				ministatement = "" if ministatement=="{}"

     (1 .. count).map{|x| direction }.join("") + ministatement

    end
		alias :to_s :compose
    
  end  # class


	######################## MatchStatement ################################

	MatchSAttributes = Struct.new(:match_class, :as, :where )
  class MatchStatement
    include Support
    def initialize match_class, as: 0,  **args
			reduce_class = ->(c){ c.is_a?(Class) ? c.ref_name : c.to_s }

			@q =  MatchSAttributes.new( reduce_class[match_class],  # class
								as.respond_to?(:zero?) && as.zero? ?  reduce_class[match_class].pluralize : as	,			
								args[ :where ])

			@query_stack = [ self ]
		end

		def match_alias
			"as: #{@q[:as]}"
		end



		# used for the first compose-statement of a compose-query
		def compose_simple
				where_statement = where.is_a?(String) && where.size <3 ?  nil :  "where: ( #{ generate_sql_list( @q[:where] ) })"
			'{'+ [ "class: #{@q[:match_class]}",  as , where_statement].compact.join(', ') + '}'
		end


		def << connection
			@query_stack << connection
			self  # return MatchStatement
		end
		#
		def compile &b
     "match " + @query_stack.map( &:to_s ).join + return_statement( &b )
		end


		# executes the standard-case.
		# returns
		#  * as: :hash   : an array of  hashes
		#  * as: :array  : an array of hash-values 
		#  * as  :flatten: a simple array of hash-values
		#
		# The optional block is used to customize the output. 
		# All previously defiend »as«-Statements are provided though the control variable.
		#
		# Background
		# A match query   "Match {class aaa, as: 'aa'} return aa "  
		#
		# returns [ aa: { result of the query, a Vertex or a value-item  }, aa: {}...}, ...] ]
		# (The standard case)
		#
		# A match query   "Match {class aaa, as: 'aa'} return aa.name "  
		# returns [ aa.name: { name  }, aa.name: { name }., ...] ]
		# 
		# Now, execute( as: :flatten){ "aa.name" }  returns
		#  [name1, name2 ,. ...]
		#
		#
		# Return statements  (examples from https://orientdb.org/docs/3.0.x/sql/SQL-Match.html)
		#  "person.name as name, friendship.since as since, friend.name as friend"
		#
		#  " person.name + \" is a friend of \" + friend.name as friends"
		#
		#  "$matches"
		#  "$elements"
		#  "$paths"
		#  "$pathElements"
		#
		#    
		#
		def execute as: :hash, &b 
			r = V.db.execute{ compile &b }
			case as
			when :hash
				r
			when :array
			 r.map{|y| y.values}
			when :flatten
			 r.map{|y| y.values}.orient_flatten 
			else
				raise ArgumentError, "Specify parameter «as:» with :hash, :array, :flatten"
		 end
		end
#		def compose
#
#			'{'+ [ "class: #{@q[:match_class]}", 
#					"as: #{@as}" , where, while_s, 
#						@maxdepth >0 ? "maxdepth: #{maxdepth}": nil  ].compact.join(', ')+'}'
#		end

		alias :to_s :compose_simple


##  return_statement
		#
		# summarizes defined as-statements ready to be included as last parameter
		# in the match-statement-stack
		#
		# They can be modified through a block.
		#
		# i.e
		#
		# t= TestQuery.match(  where: {a: 9, b: 's'}, as: nil ) << E.connect("<-", as: :test) 
		# t.return_statement{|y| "#{y.last}.name"} 
		#
		# =>> " return  test.name"
		#
		#return_statement is always called through compile
		#
		# t.compile{|y| "#{y.last}.name"} 

 private		
		def return_statement
			resolve_as = ->{  		@query_stack.map{|s| s.as.split(':').last unless s.as.nil? }.compact }
			" return " + statement = if block_given? 
										a= yield resolve_as[] 
										a.is_a?(Array) ? a.join(', ') :  a
									else
										resolve_as[].join(', ')
									end

			
		end
		
	end  # class


	######################## OrientQuery ###################################

	QueryAttributes =  Struct.new( :kind,  :projection, :where, :let, :order, :while, :misc, 
																:class, :return,  :aliases, :database, 
																:set, :remove, :group, :skip, :limit, :unwind )
	
	class OrientQuery
    include Support


#
    def initialize  **args
			@q =  QueryAttributes.new args[:kind] ||	'select' ,
								[], #		 :projection 
								[], # :where ,
								[], # :let ,
								[], # :order,
								[], # :while,
								[] , # misc
								'',  # class
								'',  #  return
								[],   # aliases
								'',  # database
								[],   #set,
								[]  # remove
			  args.each{|k,v| send k, v}
				@fill = block_given? ?   yield  : 'and'
		end
		

=begin
  where: "r > 9"                          --> where r > 9
  where: {a: 9, b: 's'}                   --> where a = 9 and b = 's'
  where:[{ a: 2} , 'b > 3',{ c: 'ufz' }]  --> where a = 2 and b > 3 and c = 'ufz'
=end
		def method_missing method, *arg, &b   # :nodoc: 
			if method ==:while || method=='while'
				while_s arg.first
			else
				@q[:misc] << method.to_s <<  generate_sql_list(arg) 
			end 
			self
    end

		def misc   # :nodoc:
			@q[:misc].join(' ') unless @q[:misc].empty?
		end

    def subquery  # :nodoc: 
      nil
    end

	
		def kind value=nil
			if value.present?
				@q[:kind] = value
				self
			else
			@q[:kind]
			end
		end
=begin
  Output the compiled query
  Parameter: destination (rest, batch )
  If the query is submitted via the REST-Interface (as get-command), the limit parameter is extracted.
=end

		def compose(destination: :batch)
			if kind.to_sym == :update 
				return_statement = "return after " + ( @q[:aliases].empty? ?  "$current" : @q[:aliases].first.to_s)
				[ 'update', target, set, remove, return_statement , where, limit ].compact.join(' ')
			elsif kind.to_sym == :update!
				[ 'update', target, set,  where, limit, misc ].compact.join(' ')
			elsif kind.to_sym == :create
				[ "CREATE VERTEX", target, set ].compact.join(' ')
			#	[ kind, target, set,  return_statement ,where,  limit, misc ].compact.join(' ')
			elsif kind.to_sym == :upsert 
				return_statement = "return after " + ( @q[:aliases].empty? ?  "$current" : @q[:aliases].first.to_s)
				[ "update", target, set,"upsert",  return_statement , where, limit, misc  ].compact.join(' ')
				#[ kind,  where, return_statement ].compact.join(' ')
			elsif destination == :rest
				[ kind, projection, from, let, where, subquery,  misc, order, group_by, unwind, skip].compact.join(' ')
			else
				[ kind, projection, from, let, where, subquery,  while_s,  misc, order, group_by, limit, unwind, skip].compact.join(' ')
			end
		end
		alias :to_s :compose


		def to_or
			compose.to_or
		end

		def target arg =  nil
			if arg.present?
				@q[:database] =  arg
				self # return query-object
			elsif @q[:database].present? 
				the_argument =  @q[:database]
				case @q[:database]
									when ActiveOrient::Model   # a single record
										the_argument.rrid
									when self.class	      # result of a query
										' ( '+ the_argument.compose + ' ) '
									when Class
										the_argument.ref_name
									else
										if the_argument.to_s.rid?	  # a string with "#ab:cd"
											the_argument
										else		  # a database-class-name
											the_argument.to_s  
										end
									end
			else
				raise "cannot complete until a target is specified"
			end
		end

=begin
	from can either be a Databaseclass to operate on or a Subquery providing data to query further
=end
		def from arg = nil
			if arg.present?
				@q[:database] =  arg
				self # return query-object
			elsif  @q[:database].present? # read from
				"from #{ target }"
			end
		end


		def order  value = nil
			if value.present?
				@q[:order] << value
				self
			elsif @q[:order].present?

				"order by " << @q[:order].compact.flatten.map do |o|
					case o
					when String, Symbol, Array
						o.to_s
					else
						o.map{|x,y| "#{x} #{y}"}.join(" ")
					end  # case
				end.join(', ')
			else
				''
			end # unless
		end	  # def


    def database_class            # :nodoc:
  	    @q[:database]
    end

    def database_class= arg   # :nodoc:
  	  @q[:database] = arg 
    end

		def distinct d
			@q[:projection] << "distinct " +  generate_sql_list( d ){ ' as ' }
			self
		end

class << self
		def mk_simple_setter *m
			m.each do |def_m|
				define_method( def_m ) do | value=nil |
						if value.present?
							@q[def_m]  = value
							self
						elsif @q[def_m].present?
						 "#{def_m.to_s}  #{generate_sql_list(@q[def_m]){' ,'}}"
						end
				end
			end
		end
		def mk_std_setter *m
			m.each do |def_m|
				define_method( def_m  ) do | value = nil |
					if value.present?
						@q[def_m] << case value
													when String
														value
													when ::Hash
														value.map{|k,v| "#{k} = #{v.to_or}"}.join(", ")
													else
														raise "Only String or Hash allowed in  #{def_m} statement"
													end
						self
					elsif @q[def_m].present?
						"#{def_m.to_s} #{@q[def_m].join(',')}"	
					end # branch
				end     # def_method
			end  # each
		end  #  def
end # class << self
		mk_simple_setter :limit, :skip, :unwind 
		mk_std_setter :set, :remove

		def let       value = nil
			if value.present?
				@q[:let] << value
				self
			elsif @q[:let].present?
				"let " << @q[:let].map do |s|
					case s
					when String
						s
					when ::Hash  
						s.map do |x,y| 
							# if the symbol: value notation of Hash is used, add "$" to the key
							x =  "$#{x.to_s}"  unless x.is_a?(String) && x[0] == "$"
							"#{x} = #{ case y 
																		when self.class
																			"(#{y.compose})"
																		else
																			y.to_orient
																		end }"
						end
					end
				end.join(', ')
			end
		end
#
		def projection value= nil  # :nodoc:
			if value.present?
				@q[:projection] << value
				self
			elsif  @q[:projection].present?
				@q[:projection].compact.map do | s |
					case s
					when ::Array
						s.join(', ')
					when String, Symbol
						s.to_s
					when ::Hash
						s.map{ |x,y| "#{x} as #{y}"}.join( ', ')
					end
				end.join( ', ' )
			end
		end

			
		
	  def group value = nil
			if value.present?
     	@q[:group] << value
			self
			elsif @q[:group].present?
			 "group by #{@q[:group].join(', ')}"
			end
    end
 
		alias order_by order 
		alias group_by group
		
		def get_limit  # :nodoc: 
    	@q[:limit].nil? ? -1 : @q[:limit].to_i
    end

		def expand item
			@q[:projection] =[ " expand ( #{item.to_s} )" ]
			self
    end

		# connects by adding {in_or_out}('edgeClass')
		def connect_with in_or_out, via: nil
			 argument = " #{in_or_out}(#{via.to_or if via.present?})"
		end
		# adds a connection
		#  in_or_out:  :out --->  outE('edgeClass').in[where-condition] 
		#              :in  --->  inE('edgeClass').out[where-condition]

		def nodes in_or_out = :out, via: nil, where: nil, expand: true
			 condition = where.present? ?  "[ #{generate_sql_list(where)} ]" : ""
			 start =  if in_or_out  == :in
									'inE'
								elsif in_or_out ==  :out
									'outE'
								else
									"both"
								end
			 the_end =  if in_or_out == :in 
										'.out' 
									elsif in_or_out == :out
										'.in'
									else
										''
									end
			 argument = " #{start}(#{[via].flatten.map(&:to_or).join(',') if via.present?})#{the_end}#{condition} "

			 if expand.present?
				 send :expand, argument
			 else
				 @q[:projection]  << argument 
			 end
			 self
		end


		# returns nil if the query was not sucessfully executed
		def execute(reduce: false)
			#puts "Compose: #{compose}"
			result = V.orientdb.execute{ compose }
			return nil unless result.is_a?(::Array)
			result =  result.map{|x| yield x } if block_given?
			return  result.first if reduce && result.size == 1
			## standard case: return Array
			OrientSupport::Array.new( work_on: resolve_target, work_with: result.orient_flatten)   
		end
:protected
		def resolve_target
			if @q[:database].is_a? OrientSupport::OrientQuery
				@q[:database].resolve_target
			else
				@q[:database]
			end
		end

	#	end
	end # class


end # module
