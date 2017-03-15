
class Array
# Class  extentions to manage to_orient and from_orient
  def to_orient
    map( &:to_orient) # .join(',')
  end

  def from_orient
    map &:from_orient
  end

# Method missing enables fancy stuff like
# Jahr[2000 .. 2005].monat(5..7).value  (https://github.com/topofocus/orientdb_time_graph)
  def method_missing(method, *key)
    #if method == :to_int
    #  return self.first 
    #else 

    unless method == :to_hash || method == :to_str #|| method == :to_int
      return self.map{|x| x.public_send(method, *key)}
   # end
    end
  end
  # used to enable 
  # def abc *key
  # where key is a Range, an comma separated List or an item
  # aimed to support #compose_where
  def analysea # :nodoc:
    if first.is_a?(Range) 
     first
    elsif size ==1
      first
    else
      self
    end

  end
end
class Hash #WithIndifferentAccess
  def from_orient
    substitute_hash = HashWithIndifferentAccess.new
    #keys.each{|k| puts self[k].inspect}
    keys.each{|k| substitute_hash[k] = self[k].from_orient}
    substitute_hash
  end

  def to_orient
    #puts "here hash"
    substitute_hash = Hash.new
    keys.each{|k| substitute_hash[k] = self[k].to_orient}
    substitute_hash
  end

  def nested_under_indifferent_access
    HashWithIndifferentAccess.new self
  end
end
class Symbol
  def from_orient
    self
  end
  def to_a
    [ self ]
  end
  # symbols are masked with ":{symbol}:"
  def to_orient
    ":"+self.to_s+":"
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

class NilClass
  def to_orient
    self
  end
  def from_orient
    nil
  end


class Date
  def to_orient
    if RUBY_PLATFORM == 'java'
      java.util.Date.new( year-1900, month-1, day , 0, 0 , 0 )  ## Jahr 0 => 1900
    else
      self
    end
  end
  def from_orient
    self
  end
end

end

class Numeric
  def from_orient
    self
  end

  def to_orient
    self
  end

  def to_or
   "#{self.to_s}"
  end

  def to_a
    [ self ]
  end
end

class String
  def capitalize_first_letter
    self.sub(/^(.)/) { $1.capitalize }
  end

  def where **args
    if rid?
      from_orient.where **args
    end
  end

  def from_orient
	  if rid?
	    ActiveOrient::Model.autoload_object self
	  elsif
	    self =~ /^:.*:$/
	    self[1..-2].to_sym
	  else
	    self
	  end
  end
# if the string contains "#xx:yy" omit quotes
  def to_orient
    if rid? 
      if self[0] == "#"
	self
      else
	"#"+self
      end
    else
       self   # return the sting (not the quoted string. this is to_or)
    end
    #self.gsub /%/, '(percent)'
   # quote 
  end

  # a rid is either #nn:nn or nn:nn
  def rid?
    self =~ /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
  end

#  return a valid rid or nil
  def rid
    rid? ? self : nil
  end

  def to_classname
    if self[0] == '$'
      self[1..-1]
    else
      self
    end
  end

  def to_or
   quote
  end
  
  def to_a
    [ self ]
  end

    def quote
      str = self.dup
      if str[0, 1] == "'" && str[-1, 1] == "'"
	self
      else
	last_pos = 0
	while (pos = str.index("'", last_pos))
	  str.insert(pos, "\\") if pos > 0 && str[pos - 1, 1] != "\\"
	  last_pos = pos + 1
	end
	"'#{str}'"
      end
    end


end


#class RecordList
#  def from_orient
#      map &:from_orient
#  end
#end
if RUBY_PLATFORM == 'java'

## JavaMath:.BigDecimal does not premit mathematical operations
## We convert it to RubyBigDecimal to represent it (if present in the DB) and upon loading from the DB

class Java::JavaMath::BigDecimal
  def to_f
    BigDecimal.new self.to_s 
  end

  def from_orient
    BigDecimal.new self.to_s
  end
  
end
  class Java::ComOrientechnologiesOrientCoreDbRecordRidbag::ORidBag
    def from_orient
      to_a.from_orient
    end
  end
  
  class Java::ComOrientechnologiesOrientCoreDbRecord::OTrackedList
 #  class  RecordList
    #   Basisklasse
    #   Java::ComOrientechnologiesOrientCoreDbRecord::ORecordLazyList
    #	Methode get(Index):  gibt das Dokument (Java::ComOrientechnologiesOrientCoreRecordImpl::ODocument) zurück
    ## base = ActiveOrient::Model::Base.first
    ## base.document.first_list
    # => #<OrientDB::RecordList:[#21:0, #22:0, #23:0, #24:0, #21:1, #22:1, #23:1, #24:1, #21:2, #22:2]> 
    ## base.first_list.get(3)
    # => <OrientDB::Document:first_list:#24:0 second_list:#<OrientDB::RecordList:[#27:17, #28:17, #25:18, #26:18, #27:18, #28:18, #25:19, #26:19, #27:19, #28:19]> label:3> 
    ## base.first_list[3]
    #  => #<ActiveOrient::Model::FirstList:0x18df26a1  (...)
    ## base.first_list[3].second_list[5]
    #   => #<ActiveOrient::Model::SecondList: (...)
    ##  base.first_list.get(3).second_list.get(5)
    #    => <OrientDB::Document:second_list:#28:18 label:5> 
    #
    def from_orient
      map &:from_orient
      self
    end
    def to_orient
      self
    end

    #def add value
    #  puts "ASDSD"
    #end
    #
    def to_a
      super.map &:from_orient
    end
    def first
      super.from_orient
    end
    def last
      super.from_orient
    end
    def [] val
	super.from_orient

    end

    def << value
      #put "I will perform the insert"
      value =  value.document if value.is_a?( ActiveOrient::Model ) && value.document.present?
      add value
      #save

    end
  end

  class Java::ComOrientechnologiesOrientCoreDbRecord::OTrackedMap
    def from_orient

 #     puts self.inspect
  #    puts self.keys.inspect
     HashWithIndifferentAccess.new(self)
    #  Kernel.exit
#      map &:from_orient
     # to_a.from_orient
    end

  end
  class Java::JavaUtil::Date
    def from_orient
      Date.new(year+1900, month+1, date )
    end
    def to_orient
      self
    end
  end


end

