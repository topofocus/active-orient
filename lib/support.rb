class String
  def to_classname
    if self[0] =='$'
      self[1..-1]
    else
      self.camelize 
    end
  end
  def to_orient
    self.gsub /%/, '(percent)'

  end
    def rid? 
      self =~  /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/   
    end
    def from_orient
	if rid? 
	  ActiveOrient::Model.autoload_object  self
	else
	  self
	end
    end
end
class NilClass
  def to_orient
   self 
  end
end
class Symbol
  def to_orient
    self.to_s.to_orient
  end
  def from_orient
    self
  end
end

class Numeric
  def from_orient
    self
  end
  def to_orient
    self
  end
end

class Time 
  def from_orient
    self
  end
  def to_orient
    self
  end
end
class Date
  def from_orient
    self
  end
  def to_orient
    self
  end
end

class TrueClass
  def from_orient
    self
  end
  def to_orient
    self
  end
end
class FalseClass
  def from_orient
    self
  end
  def to_orient
    self
  end
end

class Array
    def to_orient
      map &:to_orient
    end
    def from_orient
      map &:from_orient
    end
end
class Hash #WithIndifferentAccess
  def from_orient
    substitute_hash = HashWithIndifferentAccess.new
    keys.each{ |k| puts self[k].inspect }
    keys.each{| k | substitute_hash[k] =  self[k].from_orient  }
    substitute_hash	      

  end
  def to_orient
    substitute_hash = Hash.new
    keys.each{| k | substitute_hash[k] =  self[k].to_orient  }
    substitute_hash	      

  end

    def nested_under_indifferent_access
        HashWithIndifferentAccess.new self
    end
end


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
      arg=arg.flatten
      return "" if arg.blank? || arg.size == 1 && arg.first.blank?
     "where " + arg.map do |issue|
       case issue
       when String
	  issue
       when Hash
	 generate_sql_list issue
      end
     end.join( ' and ' )
    end
    def generate_sql_list attributes={}
      attributes.map do | key, value |
	case value
	when Numeric
	  key.to_s << " = " << value.to_s 
	else #  String, Symbol, Date, Time, Trueclass, Falseclass ...
	  key.to_s << ' = ' << "\'#{ value }\'"
	end
      end.join( ' and ' )
    end
    end  # module


    class OrientQuery

    include Support

      def initialize  **args
	@projection = []
	@misc= []
	args.each do | k,v|
	self.send k, v
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

      def compose
	[ "select", projection,  from, where , subquery,  misc, order , group_by, unwind, skip ].compact.join(' ')
      end
=begin
from can either be a Databaseclass to operate on or a Subquery providing data to query further 
=end
      def from arg=nil
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
			nil # don't set @database
		      end
	  @from =  arg
	else # read from
	  "from " << if  @from.is_a?( OrientQuery )
		       "( #{@from.compose} )"
	  else 
	    @database.to_s
	  end
	end
      end
      def database_class= arg
	@database =  arg if @database.present?
	if @from.is_a? OrientQuery
	  @from.database_class= arg
	end
      end
      def database_class
	if @database.present?
	  @database
	elsif @from.is_a? OrientQuery
	  @from.database_class
	else
	  nil
	end
      end


=begin
Call where without a parameter to request the saved where-string

to create the where-part of the query a string, a hash or an Array is supported

where: "r > 9"                          --> where r > 9
where: {a: 9, b: 's'}                   --> where a = 9 and b = 's'
where:[{ a: 2} , 'b > 3',{ c: 'ufz' }]  --> where a = 2 and b > 3 and c = 'ufz'
=end
      def where *arg
	@where= compose_where(*arg) unless arg.empty?
	@where  # return_value
      end

      def let *arg
#	SELECT FROM Profile
#	LET $city = address.city
#	WHERE $city.name like '%Saint%"' AND
#	    ( $city.country.name = 'Italy' OR $city.country.name = 'France' )
	puts "OrientSupport::OrientQuery@let is not implementated"
      end
      def distinct d=nil
	if d.present?
	@projection << case d
			    when String
			        "distinct( #{d} )"  
			    when Array
			        "distinct( #{d.first} ) as #{d.last}"
			    when Hash
			        "distinct( #{d.first.first} ) as #{d.first.last}"
			    else
			      ""
			    end 
	end
	#### error? distinct returns projection, what if both are present in a query?
	@projection.join(',')  #return_value
      end
      def projection s=nil
	if s.present?

	  @projection <<  case s
			  when Hash
			    s.map{ |x,y| "#{x} as #{y}"}.join( ', ')
			  when Array
			    s.join(', ')
			  else
			    s
			  end

	end
      	@projection.join(', ')
      end

 #     def where= w

 #     end
#        select_string = ("select " + select_string + distinct_string + ' from ' + class_name(o_class) ).squeeze(' ')
#	where_string =  compose_where( where )
      def group_by g=nil
	@group = "group_by  #{g.to_s}" if g.present?
	# only a string is allowed
	@group  # return_value
      end
      def unwind u=nil
	@unwind = "unwind  #{u.to_s}" if u.present?
	# only a string is allowed
	@unwind  # return_value
      end

      def skip n=nil
	@skip= n if n.present?
	"skip #{@skip}" if @skip.present?
      end

      def order o=nil
	@order_string = "order by " << case o
	when  Hash 
	  o.map{ |x,y| "#{x} #{y}" }.join( " " )
	when Array
	  o.map{ |x| "#{x} asc"}.join( " " )
	else
	  o.to_s
	end if o.present?
	@order_string
      end
#	misc_string = if skip > 0 && limit > 0 
#			" skip: #{skip} "
#		      else
#			""
#		      end
#	#
#
#      def compose
#
#      end

    end
  end # module
