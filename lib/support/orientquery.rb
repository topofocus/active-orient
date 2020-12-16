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
	end  # module 


  class MatchConnection
    attr_accessor :as
    def initialize edge: nil, direction: :both, as: nil, count: 1
      @edge = edge.is_a?( Class ) ?  edge.ref_name : edge.to_s
      @direction = direction  # may be :both, :in, :out
      @as =  as
      @count =  count
    end

    def direction= dir
      @direction =  dir
    end


		def direction
			fillup =  @edge.present? ? @edge : ''
			case @direction
			when :both
				" -#{fillup}- "
			when :in
				" <-#{fillup}- "
			when :out
				" -#{fillup}-> "
      when :both_vertex
				".bothV() "
			when :out_vertex
				".outV() "
			when :in_vertex
				".inV() "
     when :both_edge
			 ".bothE(#{fillup}) "
			when :out_edge
				".outE(#{fillup}) "
			when :in_edge
				".inE(#{fillup}) "
			end

		end

    def compose
      ministatement = @as.present? ? "{ as: #{@as} } " : "" 
     (1 .. @count).map{|x| direction }.join("{}") << ministatement

    end
    
  end  # class

  class MatchStatement
    include Support
    attr_accessor :as
    def initialize match_class=nil, **args
			reduce_class = ->(c){ c.is_a?(Class) ? c.ref_name : c.to_s }
      @misc  = []
      @where = []
      @while = []
      @maxdepth = 0
      @as =  nil


      @match_class = reduce_class[match_class]
      @as = @match_class.pluralize if @match_class.is_a?(String)

			args.each do |k, v|
				case k
				when :as
					@as = v
				when :while
					@while << v
				when :where
					@where << v
				when :class
					@match_class = reduce_class[v]

					@as = @match_class.pluralize
				else
					self.send k, v
				end
			end
		end
    

		def match_alias
			"as: #{@as }"
		end
		def while_s  value=nil
				if value.present?
					@while << value
					self
				elsif @while.present?
					"while: ( #{ generate_sql_list( @where ) }) "
				end
		end

#		alias while while_s
		
		def where  value=nil
				if value.present?
					@where << value
					self
				elsif @where.present?
					"where: ( #{ generate_sql_list( @where ) }) "
				end
		end

		def maxdepth=x
			@maxdepth = x
		end

		def method_missing method, *arg, &b
			if @misc[ method.to_s ].present?
				 @misc[ method.to_s ] =   @misc[ method.to_s ] + 'and '+generate_sql_list(arg) 
			else	
				@misc << method.to_s <<  generate_sql_list(arg) 
			end
		end

		def misc
			@misc.join(' ') unless @misc.empty?
		end
		# used for the first compose-statement of a compose-query
		def compose_simple
			'{'+ [ "class: #{@match_class}", "as: #{@as}" , where ].compact.join(', ') + '}'
		end

		def compose

			'{'+ [ "class: #{@match_class}", 
					"as: #{@as}" , where, while_s, 
						@maxdepth >0 ? "maxdepth: #{maxdepth}": nil  ].compact.join(', ')+'}'
		end
		alias :to_s :compose
	end  # class


	QueryAttributes =  Struct.new( :kind, :projection, :where, :let, :order, :while, :misc, 
																:match_statements, :class, :return,  :aliases, :database, 
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
								[],  # match_statements
								'',  # class
								'',  #  return
								[],   # aliases
								'',  # database
								[],   #set,
								[]  # remove
			  args.each{|k,v| send k, v}
				@fill = block_given? ?   yield  : 'and'
		end
		
		def start value
					@q[:kind] = :match
					@q[:match_statements] = [ MatchStatement.new( value) ]
					#  @match_statements[1] = MatchConnection.new
					self
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
(only if kind == :match): connect

Add a connection to the match-query

A Match-Query alwas has an Entry-Stratement and maybe other Statements.
They are connected via " -> " (outE), "<-" (inE) or "--" (both).

The connection method adds a connection to the statement-stack. 

Parameters:
  direction: :in, :out, :both
          	 :in_edge, :out_edge, :both_edge, 
						 :in_vertex, :out_vertex, :both_vertex
  edge_class: to restrict the Query on a certain Edge-Class
  count: To repeat the connection
  as:  Includes a micro-statement to finalize the Match-Query
       as: defines a output-variablet, which is used later in the return-statement

The method returns the OrientSupport::MatchConnection object, which can be modified further.
It is compiled by calling compose
=end

		def connect direction, edge_class: nil, count: 1, as: nil
			 direction= :both unless [ :in, :out, :in_edge, :out_edge, :both_edge, :in_vertex, :out_vertex, :both_vertex].include? direction
			match_statements <<  OrientSupport::MatchConnection.new( direction: direction, edge: edge_class,  count: count, as: as)
			self  #  return the object
		end

=begin
(only if kind == :match): statement

A Match Query consists of a simple start-statement
( classname and where-condition ), a connection followd by other Statement-connection-pairs.
It performs a sub-query starting at the given entry-point.

Statement adds a statement to the statement-stack.
Statement returns the created OrientSupport::MatchStatement-record for further modifications. 
It is compiled by calling »compose«. 

OrientSupport::OrientQuery collects any "as"-directive for inclusion  in the return-statement

Parameter (all optional)
 Class: classname, :where: {}, while: {}, as: string, maxdepth: >0 , 

=end
	def statement match_class= nil, **args
		match_statements <<  OrientSupport::MatchStatement.new( match_class, args )
		self  #  return the object
	end
=begin
  Output the compiled query
  Parameter: destination (rest, batch )
  If the query is submitted via the REST-Interface (as get-command), the limit parameter is extracted.
=end

		def compose(destination: :batch)
			if kind.to_sym == :match
				unless @q[:match_statements].empty?
					match_query =  kind.to_s.upcase + " "+ @q[:match_statements][0].compose 
					match_query << @q[:match_statements][1..-1].map( &:compose ).join
					match_query << " RETURN "<< (@q[:match_statements].map( &:as ).compact | @q[:aliases]).join(', ')
				end
			elsif kind.to_sym == :update 
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
					@q[:where] << value
				end
				self
			elsif @q[:where].present?
				"where #{ generate_sql_list( @q[:where] ){ @fill } }"
			end
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


		def execute(reduce: false)
			result = V.orientdb.execute{ compose }
			result =  result.map{|x| yield x } if block_given?
			result =  result.first if reduce && result.size == 1
			if result.is_a?( ::Array)# && result.detect{|o| o.respond_to?( :rid?) && o.rid? }  
				OrientSupport::Array.new( work_on: resolve_target, work_with: result.orient_flatten)   
			else
				result
			end
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
