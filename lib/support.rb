class String
  def to_classname
    if self[0] =='$'
      self[1..-1]
    else
      self.camelize
    end
  end
  def to_orient
    self
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
    def compose_where *arg
      #puts "arg: #{arg.inspect}"
      return "" if arg.blank? || arg.size == 1 && arg.first.blank?
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
