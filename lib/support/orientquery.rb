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
      arg = arg.flatten
      return "" if arg.blank? || arg.size == 1 && arg.first.blank?
      "where " + generate_sql_list( arg , &b)
    end

=begin
designs a list of "Key =  Value" pairs combined by "and" or the binding  provided by the block
   ORD.generate_sql_list  where: 25 , upper: '65' 
    => "where = 25 and upper = '65'"
   ORD.generate_sql_list(  con_id: 25 , symbol: :G) { ',' } 
    => "con_id = 25 , symbol = 'G'"
=end
		def generate_sql_list attributes = {}, &b
			fill = block_given? ? yield : 'and'
			a=	case attributes 
					when ::Hash
						attributes.map do |key, value|
							case value
							when ActiveOrient::Model
								"#{key} = #{value.rrid}"
							when Numeric
								"#{key} = #{value}"
							when ::Array
								"#{key} in [#{value.to_orient}]"
							when Range
								"#{key} between #{value.first} and #{value.last} " 
							when DateTime
								"#{key} = date(\'#{value.strftime("%Y%m%d%H%M%S")}\',\'yyyyMMddHHmmss\')"
							when Date
								"#{key} = date(\'#{value.to_s}\',\'yyyy-MM-dd\')"
							else #  String, Symbol, Time, Trueclass, Falseclass ...
								"#{key} = \'#{value.to_s}\'"
							end
						end.join(" #{fill} ")
					when ::Array
						attributes.map{|y| generate_sql_list y, &b }.join( " #{fill} " )
					when String
						attributes
					end		
		end
  end


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
      end

    end

    def compose
      ministatement = @as.present? ? "{ as: #{@as} } " : "" 
     (1 .. @count).map{|x| direction }.join("{}") << ministatement

    end
    
  end

  class MatchStatement
    include Support
    attr_accessor :as
    attr_accessor :where
    def initialize match_class=nil, **args
			reduce_class = ->(c){ c.is_a?(Class) ? c.ref_name : c.to_s 
}
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
    
        def while_s
  	  compose_where( @while ).gsub( /where/, 'while:(' )<< ")" unless @while.blank?
    end

    def match_alias
      "as: #{@as }"
    end
    def where_s
  	  compose_where( @where ).gsub( /where/, 'where:(' )<< ")"  unless @where.blank?
    end
  
    def maxdepth=x
      @maxdepth = x
    end

    def method_missing method, *arg, &b
      @misc << method.to_s <<  generate_sql_list(arg) 
    end

    def misc
      @misc.join(' ') unless @misc.empty?
    end
    # used for the first compose-statement of a compose-query
    def compose_simple
   '{'+ [ "class: #{@match_class}", 
	       "as: #{@as}" , 
	       where_s ].compact.join(', ') + '}'
    end

    def compose

        '{'+ [ "class: #{@match_class}", 
	       "as: #{@as}" , 
	       where_s, 
	      while_s, 
	      @maxdepth >0 ? "maxdepth: #{maxdepth}": nil  ].compact.join(', ')+'}'
    end
    alias :to_s :compose
end


	QueryAttributes =  Struct.new( :kind, :projection, :where, :lett, :order, :while, :misc, 
																:match_statements, :class, :return,  :aliases, :database, 
																:group, :skip, :limit, :unwind  )
	
	class OrientQuery
    include Support


#    attr_accessor :where
#    attr_accessor :let
#    attr_accessor :projection
#    attr_accessor :order
#    attr_accessor :db
#    attr_accessor :match_statements
#
    def initialize  **args
			@q =  QueryAttributes.new args[:kind] ||	'select' ,
								[], #		 :projection 
								[], # :where ,
								[], # :let ,
								[], # :order,
								[], # :while],
								[] , # misc
								[],  # match_statements
								'',  # class
								'',  #  return
								'',   # aliases
								''  # database
			  args.each{|k,v| send k, v}
#				start( args[:start] ) if args[:start].present?

		end
#      @projection = []
#      @misc  = []
#      @let   = []
#      @where = []
#      @order = []
#      @aliases = []
#      @match_statements = []
#      @class =  nil
#			@return = nil
#			@db = nil
#      @kind  = 'select'
#
#			modify args
#
#			end

		def modify args
      args.each do |k, v|
        case k
				when :projection
					@q[:projection] << v
				when :let
					@q[:let] << v
				when :order
					@q[:order] << v
				when :where
					@q[:where] << v
				when :kind
					@q[:kind] = v
				when :start
					start(v)
				when :connect
					@q[:match_statements] << MatchConnection.new( **v )
				when :return
					@q[:aliases] << v
				else
					self.send k, v
				end
			end
		end
		
		def start value
					@q[:kind] = :match
					@q[:match_statements] = [ MatchStatement.new( **v) ]
					#  @match_statements[1] = MatchConnection.new

		end

=begin
  where: "r > 9"                          --> where r > 9
  where: {a: 9, b: 's'}                   --> where a = 9 and b = 's'
  where:[{ a: 2} , 'b > 3',{ c: 'ufz' }]  --> where a = 2 and b > 3 and c = 'ufz'
=end
		def method_missing method, *arg, &b   # :nodoc: 
      @q[:misc] << method.to_s <<  generate_sql_list(arg) 
    end


    def misc   # :nodoc:
      @q[:misc].join(' ') unless @q[:misc].empty?
    end

    def subquery  # :nodoc: 
      nil
    end

	 def kind value=nil
		 if value.present?
			 @q[:kind] =  value
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
  edge_class: to restrict the Query on a certain Edge-Class
  count: To repeat the connection
  as:  Includes a micro-statement to finalize the Match-Query
       as: defines a output-variablet, which is used later in the return-statement

The method returns the OrientSupport::MatchConnection object, which can be modified further.
It is compiled by calling compose
=end

		def connect direction, edge_class: nil, count: 1, as: nil
			direction= :both unless [ :in, :out].include? direction
			match_statements <<  OrientSupport::MatchConnection.new( direction: direction, count: count, as: as)
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
					match_query =  kind.to_s.upcase + " "+ @q[:match_statements[0]].compose_simple 
					match_query << @q[:match_statements[1..-1]].map( &:compose ).join
					match_query << " RETURN "<< (@q[:match_statements].map( &:as ).compact | @q[:aliases]).join(', ')
				end
			elsif kind.to_sym == :update
				return_statement = "return after " + ( @q[:aliases].empty? ?  "$this" : @q[:aliases].first.to_s)
				[ kind, @q[:database], misc, where, return_statement ].compact.join(' ')
			elsif destination == :rest
				[ kind, projection, from, let, where, subquery, misc, order, group_by, unwind, skip].compact.join(' ')
			else
				[ kind, projection, from, let, where, subquery, misc, order, group_by, limit, unwind, skip].compact.join(' ')
			end
		end
		alias :to_s :compose

=begin
	from can either be a Databaseclass to operate on or a Subquery providing data to query further
=end


		def from arg = nil
			if arg.present?
			@q[:database] = case arg
											when ActiveOrient::Model   # a single record
													arg.rrid
												when OrientQuery	      # result of a query
													' ( '+ arg.to_s + ' ) '
												when Class
													arg.ref_name
												else
													if arg.to_s.rid?	  # a string with "#ab:cd"
														arg
													else		  # a database-class-name
														arg.to_s  
													end
												end
			elsif  @q[:database].present? # read from
				"from #{@q[:database]}" 
			end
		end

    def database_class            # :nodoc:
  	    @q[:database]
    end

    def database_class= arg   # :nodoc:
  	  @q[:database] = arg 
    end

		def where  value=nil     # :nodoc:
			if value.present?
				@q[:where] << value
				self
			else
				compose_where @q[:where]
			end
		end

    def let       value = nil
			if value.present?
				@q[:lett] << value
			elsif @q[:lett].present?
				"let " << @q[:lett].map do |s|
					case s
					when String
						s
					when ::Array
						s.join(',  ')
					when ::Hash  ### is not recognized in jruby
						#	      else
						s.map{|x,y| "$#{x} = (#{y})"}.join(', ')
					end
				end.join(', ')
			end
		end

		def distinct d
			@q[:projection] <<  case d
													when String, Symbol
														"distinct #{d.to_s} "
													else
														dd= d.to_a.flatten
														"distinct  #{dd.first.to_s}  as #{dd.last}"
													end
			self
		end

		def projection value= nil  # :nodoc:
			if value.present?
				@q[:projection] << value
			elsif  @q[:projection].present?
				@q[:projection].compact.map do | s |
					case s
					when Array
						s.join(', ')
					when String, Symbol
						s.to_s
					else
						s.map{ |x,y| "#{x} as #{y}"}.join( ', ')
					end
				end.join( ', ' )
			end
		end

    def limit l=nil
			if l.present?
  	  @q[:limit] = "limit #{l.to_s}"
			elsif  @q[:limit].present?
				@q[:limit]
			end
  	# only a string is allowed
    end

    def get_limit  # :nodoc: 
    	@q[:limit].nil? ? -1 : @limit.split(' ').last.to_i
    end

		def expand item
			@q[:projection] =[ " expand ( #{item.to_s} )" ]
    end

		# connects by adding {in_or_out}('edgeClass')
		def connect_with in_or_out, via: nil
			 argument = " #{in_or_out}(#{via.to_or if via.present?})"
		end
		# adds a connection
		#  in_or_out:  :out --->  outE('edgeClass').in[where-condition] 
		#              :in  --->  inE('edgeClass').out[where-condition]

		def nodes in_or_out = :out, via:  nil, where: nil, expand: true
			 condition = where.present? ?  "[ #{generate_sql_list(where)} ]" : ""
			 start =  in_or_out 
			 the_end =  in_or_out == :in ? :out : :in
			 argument = " #{start}E(#{via.to_or if via.present?}).#{the_end}#{condition} "

			 if expand.present?
				 send :expand, argument
			 else
			 @q[:projection]  << argument 
			 end
			 compose
		end

    def group_by g = nil
     	@q[:group] = "group by #{g.to_s}" if g.present?
    end

    def unwind u = nil
  	  @q[:unwind] = "unwind #{u.to_s}" if u.present?
    end

    def skip n = nil
			if n.present?
  	  @q[:skip] = n if n.present?
			elsif @q[:skip].present?
				"skip #{@q[:skip]}"
			end
    end

		def order  value = nil
			if value.present?
				@q[:order] << value
			elsif @q[:order].present?
				
				# the [@order] is nessesary to enable query.order= "..." oder query.order= { a: :b }
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
		end # class


end # module
