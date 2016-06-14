require 'active_support/inflector'
module OrientSupport
  module Support

=begin
  supports
  where: 'string'
  where: { property: 'value', property: value, ... }
  where: ['string, { property: value, ... }, ... ]
  Used by update and select
=end

## ORD.compose_where 'z=34', {u:6}
    # => "where z=34 and u = 6" 
    #
    def compose_where *arg
      arg = arg.flatten
      return "" if arg.blank? || arg.size == 1 && arg.first.blank?
      "where " + arg.map do |issue|
        case issue
        when String
	        issue
        when Hash
	        generate_sql_list issue
        end
      end.join(' and ')
    end

=begin
designs a list of "Key =  Value" pairs combined by "and" or the fillword provided by the block
   ORD.generate_sql_list  where: 25 , upper: '65' 
    => "where = 25 and upper = '65'"
   ORD.generate_sql_list(  con_id: 25 , symbol: :G) { ',' } 
    => "con_id = 25 , symbol = 'G'"
=end
    def generate_sql_list attributes = {}
      fill = block_given? ? yield : 'and'
      attributes.map do |key, value|
	      case value
	      when ActiveOrient::Model
		"#{key} = ##{value.rid}"
	      when Numeric
          "#{key} = #{value}"
	      when Array
		"#{key}= #{value}"
	      when Date
		"#{key} = date(\'#{value.to_s}\',\'yyyy-MM-dd\')"
	      else #  String, Symbol, Time, Trueclass, Falseclass ...
          "#{key} = \'#{value.to_s}\'"
	      end
      end.join(" #{fill} ")
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
      @misc << method.to_s << " " << arg.map(&:to_s).join(' ')
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

=begin
  Call where without a parameter to request the saved where-string
  To create the where-part of the query a string, a hash or an Array is supported

  where: "r > 9"                          --> where r > 9
  where: {a: 9, b: 's'}                   --> where a = 9 and b = 's'
  where:[{ a: 2} , 'b > 3',{ c: 'ufz' }]  --> where a = 2 and b > 3 and c = 'ufz'
=end

    attr_accessor :where
    attr_accessor :let
    attr_accessor :projection
    attr_accessor :order
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

    def method_missing method, *arg, &b
      @misc << method.to_s << " " << arg.map(&:to_s).join(' ')
    end

    def misc
      @misc.join(' ') unless @misc.empty?
    end

    def subquery
      nil
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
		    when OrientQuery
		      ' ( '+ arg.to_s + ' ) '
		    else
		      ORD.classname(arg)
		    end
	compose  # return the complete query
      else # read from
	"from #{@database}" unless @database.nil?
      end
    end
    alias :from= :from

    def database_class
  	  if @database.present?
  	    @database
  	  elsif @from.is_a? OrientQuery
  	    @from.database_class
  	  else
  	    nil
  	  end
    end

    def database_class= arg
  	  @database = arg if @database.present?
  	  if @from.is_a? OrientQuery
  	    @from.database_class= arg
  	  end
    end

    def where_s
  	  compose_where @where
    end

    def let_s
  	  unless @let.empty?
  	    "let " << @let.map do |s|
  	      case s
  	      when Hash
  	        s.map{|x,y| "$#{x} = (#{y})"}.join(', ')
  	      when Array
  	        s.join(',  ')
  	      else
  	        s
  	      end
  	    end.join(', ')
  	  end
    end

    def distinct d
  	  @projection << case d
  		when String, Symbol
  		  "distinct( #{d.to_s} )"
  		when Array
  		  "distinct( #{d.first} ) as #{d.last}"
  		when Hash
  		  "distinct( #{d.first.first} ) as #{d.first.last}"
  		else
  		  ""
  		end
  	  compose  # return the hole query
    end
    alias :distinct= :distinct

    def projection_s
  	  @projection.map do | s |
  		  case s
  			when Hash
  			  s.map{ |x,y| "#{x} as #{y}"}.join( ', ')
  			when Array
  			  s.join(', ')
  			else
  			  s
  			end
  	  end.join( ', ' )
    end

    def limit l=nil
  	  @limit = "limit #{l.to_s}" if l.present?
  	# only a string is allowed
  	  @limit  # return_value
    end
    alias :limit= :limit

    def get_limit
    	@limit.nil? ? -1 : @limit.split(' ').last.to_i
    end

    def group_by g = nil
     	@group = "group by #{g.to_s}" if g.present?
  	# only a string is allowed
  	  @group  # return_value
    end

    def unwind u = nil
  	  @unwind = "unwind #{u.to_s}" if u.present?
  	# only a string is allowed
  	  @unwind  # return_value
    end

    def skip n = nil
  	  @skip = n if n.present?
  	  "skip #{@skip}" if @skip.present?
    end

    def order_s
      unless @order.empty?
	# the [@order] is nessesary to enable query.order= "..." oder query.order= { a: :b }
	"order by " << [@order].flatten.map do |o|
	  case o
	  when Hash
	    o.map{|x,y| "#{x} #{y}"}.join(" ")
	  else
	    o.to_s
	  end  # case
	end.join(', ')
      else
	''
      end # unless
    end	  # def
    end # class


end # module
