
class Array
# Class  extentions to manage to_orient and from_orient
  def to_orient
    map( &:to_orient) # .join(',')
  end

  def to_or
    "["+ map( &:to_or).join(', ')+"]"
  end

  def from_orient
    map &:from_orient
  end

	def to_human
		map &:to_human
	end
  # used to enable 
  # def abc *key
  # where key is a Range, an comma separated List or an item
  # aimed to support #compose_where
  def analyse # :nodoc:
    if first.is_a?(Range) 
     first
    elsif size ==1
      first
    else
      self
    end
  end

	def orient_flatten
		while( first.is_a?(Array) )
			self.flatten!(1)
		end
		self
	end
end

class Symbol
  def to_a
    [ self ]
  end
  # symbols are masked with ":{symbol}:"
  def to_orient
    ":"+self.to_s+":"
  end
  def to_or
  "'"+self.to_orient+"'"
  end
	
	# inserted to prevent error message while initializing a model-recorda
=begin
2.6.1 :008 > ii.first.attributes
 => {:zwoebelkuchen=>[7, 9, 9, 7, 8, 8, 3, 6, 9, ":zt:", ":zt:", ":zg:", ":zg:", ":tzu:", ":grotte:"], :created_at=>Wed, 27 Mar 2019 14:59:45 +0000} 
2.6.1 :009 > ii.first.send :zwoebelkuchen
key zwoebelkuchen
iv [7, 9, 9, 7, 8, 8, 3, 6, 9, ":zt:", ":zt:", ":zg:", ":zg:", ":tzu:", ":grotte:"]
27.03.(15:00:36)ERROR->MethodMissing  -> Undefined method: coerce --  Args: [Wed, 27 Mar 2019 14:59:45 +0000]
27.03.(15:00:36)ERROR-> The Message undefined method `coerce' for :zt:Symbol
27.03.(15:00:36)ERROR->  /home/dev/topo/activeorient/lib/support/orient.rb:129:in `block in method_missing'
  /home/dev/topo/activeorient/lib/support/orient.rb:129:in `map'
  /home/dev/topo/activeorient/lib/support/orient.rb:129:in `method_missing'
  /home/ubuntu/.rvm/gems/ruby-2.6.1/gems/activesupport-5.2.2.1/lib/active_support/core_ext/date/calculations.rb:140:in `<=>'
  /home/ubuntu/.rvm/gems/ruby-2.6.1/gems/activesupport-5.2.2.1/lib/active_support/core_ext/date/calculations.rb:140:in `compare_with_coercion'
  /home/ubuntu/.rvm/gems/ruby-2.6.1/gems/activesupport-5.2.2.1/lib/active_support/core_ext/date_time/calculations.rb:208:in `<=>'
  /home/dev/topo/activeorient/lib/support/orient.rb:36:in `=='
  /home/dev/topo/activeorient/lib/support/orient.rb:36:in `key'
  /home/dev/topo/activeorient/lib/support/orient.rb:36:in `initialize'
  /home/dev/topo/activeorient/lib/base.rb:216:in `new'
  /home/dev/topo/activeorient/lib/base.rb:216:in `[]'
  /home/dev/topo/activeorient/lib/base_properties.rb:110:in `block in define_property_methods'
  (irb):9:in `irb_binding'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb/workspace.rb:85:in `eval'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb/workspace.rb:85:in `evaluate'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb/context.rb:385:in `evaluate'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb.rb:493:in `block (2 levels) in eval_input'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb.rb:647:in `signal_status'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb.rb:490:in `block in eval_input'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb/ruby-lex.rb:246:in `block (2 levels) in each_top_level_statement'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb/ruby-lex.rb:232:in `loop'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb/ruby-lex.rb:232:in `block in each_top_level_statement'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb/ruby-lex.rb:231:in `catch'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb/ruby-lex.rb:231:in `each_top_level_statement'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb.rb:489:in `eval_input'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb.rb:428:in `block in run'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb.rb:427:in `catch'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb.rb:427:in `run'
  /home/ubuntu/.rvm/rubies/ruby-2.6.1/lib/ruby/2.6.0/irb.rb:383:in `start'
  ./active-orient-console:51:in `<main>'
=end

	def coerce a  #nodoc#
	 nil	
	end
end

class Object
  def from_orient
    self
  end

  def to_orient
    self
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
end


class Numeric

  def to_or
  # "#{self.to_s}"
		self
  end

  def to_a
    [ self ]
  end
end

class String
  def capitalize_first_letter
    self.sub(/^(.)/) { $1.capitalize }
  end
### as_json has unexpected side-effects, needs further consideration
#  def as_json o=nil
#    if rid?
#      rid
#    else
#     super o
#    end
#  end

  def where **args
    if rid?
      from_orient.where **args
    end
  end

	# from orient translates the database response into active-orient objects
	#
	# symbols are representated via ":{something]:}"
	# 
	# database records respond to the "rid"-method
	#
	# other values are not modified
  def from_orient
	  if rid?
	    ActiveOrient::Model.autoload_object self
	  elsif  # symbol-representation in the database
	    self =~ /^:.*:$/
	    self[1..-2].to_sym
	  else
	    self
	  end
  end

	alias expand from_orient
# if the string contains "#xx:yy" omit quotes
  def to_orient
     rid? ? "#"+rid : self   # return the string (not the quoted string. this is to_or)
  end

  # a rid is either #nn:nn or nn:nn
  def rid?
    self =~ /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
  end

#  return a valid rid (format: "nn:mm") or nil
  def rid
      self["#"].nil? ? self : self[1..-1] if rid? 
  end
	alias rrid rid

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

	def coerce a  #nodoc#
	 nil	
	end

	def to_human
		self
	end
end

class Hash #WithIndifferentAccess

	# converts "abc" => {anything} to :abc => {anything}
	# converts "nn" => {anything} to nn => {anything}
  def to_orient   # converts hast from activeorient to db
    substitute_hash =  {} # HashWithIndifferentAccess.new
#		puts "here to hash"
    #keys.each{|k| puts self[k].inspect}
    keys.each do |k| 
			orient_k =  case k
									when Numeric
										k
									when Symbol, String
										k.to_s
									else
										nil
									end
			substitute_hash[orient_k] = self[k].to_orient
		end
    substitute_hash
  end

  def from_orient   # converts hash from db to activeorient
    #puts "here hash.from_orient --> #{self.inspect}"
		if keys.include?("@class" )
			ActiveOrient::Model.orientdb_class( name: self["@class"] ).new self
			# create a dummy class and fill with attributes from result-set
		elsif keys.include?("@type") && self["@type"] == 'd'  
			ActiveOrient::Model.orientdb_class(name: 'query' ).new self
		else
			substitute_hash = Hash.new
			keys.each do |k| 
				orient_k = if  k.to_s.to_i.to_s == k.to_s
										 k.to_i
									 else
										 k.to_sym
									 end

				substitute_hash[orient_k] = self[k].from_orient
			end
			substitute_hash
		end
	end

	# converts a hash to a string appropiate to include in raw queries
	def to_or
		"{ " + to_orient.map{|k,v| "#{k.to_s.to_or}: #{v.to_or}"}.join(',') + "}"
	end
## needs testing!!
#  def as_json o=nli
#    #puts "here hash"
#    substitute_hash = Hash.new
#    keys.each{|k| substitute_hash[k] = self[k].as_json}
#    substitute_hash
#  end
#  def nested_under_indifferent_access
#    HashWithIndifferentAccess.new self
#		self
#  end
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

