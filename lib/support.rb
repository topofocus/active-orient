module OrientSupport
  module Support
    def compose_where *arg
     " where " + arg.map do |issue|
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
	else #  String, Symbol
	  key.to_s << ' = ' << "\'#{ value }\'"
	  #	else 
	  #	  puts "ERROR, value-> #{value}, class -> #{value.class}"
	end
      end.join( ' and ' )
    end
    end  # module
  end # module
