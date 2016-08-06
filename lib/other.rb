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
      puts "I will perform the insert"
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
