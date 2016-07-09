# Class create to manage to_orient and from_orient

class Array
  def to_orient
    map &:to_orient
  end

  def from_orient
    map &:from_orient
  end

  def method_missing(method)
    unless method == :to_hash || method == :to_str
      return self.map{|x| x.public_send(method)}
    end
  end
end

#class RecordList
#  def from_orient
#      map &:from_orient
#  end
#end
if RUBY_PLATFORM == 'java'
  class Java::ComOrientechnologiesOrientCoreDbRecordRidbag::ORidBag
    def from_orient
      to_a.from_orient
    end
  end
  
  class Java::ComOrientechnologiesOrientCoreDbRecord::OTrackedList
 #  class  RecordList
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
      puts "I will perform the insert"
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
class FalseClass
  def from_orient
    self
  end

  def to_orient
    self
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
    substitute_hash = Hash.new
    keys.each{|k| substitute_hash[k] = self[k].to_orient}
    substitute_hash
  end

  def nested_under_indifferent_access
    HashWithIndifferentAccess.new self
  end
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
##module OrientDB
#class Document
#  def from_orient
#    ActiveOrient::Model.autoload_object rid
#  end
#end
#end
class NilClass
  def to_orient
    self
  end
  def from_orient
    nil
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
end

class String
  def capitalize_first_letter
    self.sub(/^(.)/) { $1.capitalize }
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
#  alias :reload! from_orient

  def to_orient
    #self.gsub /%/, '(percent)'
   # quote 
    self
  end

  # a rid is either #nn:nn and nn:nn
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

class Symbol
  def to_orient
    ":"+self.to_s+":"
  end
 ## there is no "from_orient" as symbols are stored as strings
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
