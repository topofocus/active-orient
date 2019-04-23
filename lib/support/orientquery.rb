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
      @edge = edge
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
      @misc  = []
      @where = []
      @while = []
      @maxdepth = 0
      @as =  nil


      @match_class = match_class
      @as = match_class.pluralize if match_class.is_a? String

      args.each do |k, v|
        case k
	when :as
	  @as = v
        when :while
          @while << v
        when :where
          @where << v
	when :class
	  @match_class = v
	  @as = v.pluralize
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

  class OrientQuery
    include Support


    attr_accessor :where
    attr_accessor :let
    attr_accessor :projection
    attr_accessor :order
    attr_accessor :db
    attr_accessor :match_statements

    def initialize  **args
      @projection = []
      @misc  = []
      @let   = []
      @where = []
      @order = []
      @aliases = []
      @match_statements = []
      @class =  nil
			@return = nil
			@db = nil
      @kind  = 'select'
      args.each do |k, v|
        case k
				when :projection
					@projection << v
				when :let
					@let << v
				when :order
					@order << v
				when :where
					@where << v
				when :kind
					@kind = v
				when :start
					@match_statements[0] = MatchStatement.new **v
					#  @match_statements[1] = MatchConnection.new
				when :connection
					@match_statements[1] = MatchConnection.new **v
				when :return
					@aliases << v
				else
					self.send k, v
				end
			end
		end


=begin
  where: "r > 9"                          --> where r > 9
  where: {a: 9, b: 's'}                   --> where a = 9 and b = 's'
  where:[{ a: 2} , 'b > 3',{ c: 'ufz' }]  --> where a = 2 and b > 3 and c = 'ufz'
=end
		def method_missing method, *arg, &b   # :nodoc: 
      @misc << method.to_s <<  generate_sql_list(arg) 
			self.to_s  # return compiled result
    end


    def misc   # :nodoc:
      @misc.join(' ') unless @misc.empty?
	#		self.to_s  # return compiled result
    end

    def subquery  # :nodoc: 
      nil
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
		match_statements <<  OrientSupport::MatchStatement.new( mattch_class, args )
		self  #  return the object
		
	end
=begin
  Output the compiled query
  Parameter: destination (rest, batch )
  If the query is submitted via the REST-Interface (as get-command), the limit parameter is extracted.
=end

	def compose(destination: :batch)
		if @kind == :match
			unless @match_statements.empty?
				match_query =  @kind.to_s.upcase + " "+ @match_statements[0].compose_simple 
				match_query << @match_statements[1..-1].map( &:compose ).join
				match_query << " RETURN "<< (@match_statements.map( &:as ).compact | @aliases).join(', ')
			end
		elsif @kind.to_sym == :update
			return_statement = "return after " + ( @aliases.empty? ?  "$this" : @aliases.first.to_s)
			[ @kind, @database, misc, where_s, return_statement ].compact.join(' ')
		elsif destination == :rest
			[@kind, projection_s, from, let_s, where_s, subquery, misc, order_s, group_by, unwind, skip].compact.join(' ')
		else
			[@kind, projection_s, from, let_s, where_s, subquery, misc, order_s, group_by, limit, unwind, skip].compact.join(' ')
		end
	end
	alias :to_s :compose

=begin
  from can either be a Databaseclass to operate on or a Subquery providing data to query further
=end


	def from arg = nil
		if arg.present?
			@database = case arg
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
			compose  # return the complete query
		else # read from
			"from #{@database}" unless @database.nil?
		end
	end
	alias :from= :from

    def database_class            # :nodoc:
  	  if @database.present?
  	    @database
  	  elsif @from.is_a? OrientQuery
  	    @from.database_class
  	  else
  	    nil
  	  end
    end

    def database_class= arg   # :nodoc:
  	  @database = arg if @database.present?
  	  if @from.is_a? OrientQuery
  	    @from.database_class= arg
  	  end
    end

    def where_s        # :nodoc:
  	  compose_where @where
    end

    def let_s           # :nodoc:
  	  unless @let.empty?
  	    "let " << @let.map do |s|
  	      case s
  	      when String
  	        s
  	      when Array
  	        s.join(',  ')
#	      when Hash  ### is not recognized in jruby
	      else
  	        s.map{|x,y| "$#{x} = (#{y})"}.join(', ')
  	      end
  	    end.join(', ')
  	  end
    end

    def distinct d
			@projection <<  case d
			when String, Symbol
				"distinct #{d.to_s} "
			else
				dd= d.to_a.flatten
				"distinct  #{dd.first.to_s}  as #{dd.last}"
			end
			compose
    end
    alias :distinct= :distinct

    def projection_s   # :nodoc:
  	  @projection.map do | s |
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

    def limit l=nil
  	  @limit = "limit #{l.to_s}" if l.present?
  	# only a string is allowed
  	  @limit
    end
    alias :limit= :limit

    def get_limit  # :nodoc: 
    	@limit.nil? ? -1 : @limit.split(' ').last.to_i
    end

		def expand item
			@projection =[ " expand ( #{item.to_s} )" ]
			compose
    end


		def nodes in_or_out = :out, via:  nil, where: nil, expand: true
			 condition = where.present? ?  "[ #{generate_sql_list(where)} ]" : ""
			 start =  in_or_out 
			 the_end =  in_or_out == :in ? :out : :in
			 argument = " #{start}E(#{via.to_or if via.present?}).#{the_end}#{condition} "

			 if expand.present?
				 send :expand, argument
			 else
			 @projection  << argument 
			 end
			 compose
		end

    def group_by g = nil
     	@group = "group by #{g.to_s}" if g.present?
  	# only a string is allowed
  	   @group
    end

    def unwind u = nil
  	  @unwind = "unwind #{u.to_s}" if u.present?
  	# only a string is allowed
  	  @unwind
    end

    def skip n = nil
  	  @skip = n if n.present?
  	  "skip #{@skip}" if @skip.present?
    end

    def order_s    # :nodoc:
      unless @order.empty?
	# the [@order] is nessesary to enable query.order= "..." oder query.order= { a: :b }
	"order by " << [@order].flatten.map do |o|
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
