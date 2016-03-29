module OrientSupport
  module Support

=begin
  supports
  where: 'string'
  where: { property: 'value', property: value, ... }
  where: ['string, { property: value, ... }, ... ]
  Used by update and select
=end

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

    def generate_sql_list attributes = {}
      attributes.map do |key, value|
	      case value
	      when Numeric
          "#{key} = #{value}"
	      else #  String, Symbol, Date, Time, Trueclass, Falseclass ...
          "#{key} = \'#{value}\'"
	      end
      end.join(' and ')
    end
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

    def initialize  **args
      @projection = []
      @misc  = []
      @let   = []
      @where = []
      @order = []
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
      if destination == :rest
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
  		  when Class
  			  arg.new.classname
  		  when ActiveOrient::Model
  			  classname
  		  when String
  			  arg
  		  when Symbol
  			  arg
  		  when OrientQuery
  			  ' ( '+ arg.to_s + ' ) '
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
  	  end
    end
  end

end # module
