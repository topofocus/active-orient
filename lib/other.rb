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

class Date
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

class Hash #WithIndifferentAccess
  def from_orient
    substitute_hash = HashWithIndifferentAccess.new
    keys.each{|k| puts self[k].inspect}
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

class NilClass
  def to_orient
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

  def to_or
   "#{self.to_s}"
  end
end

class String
  def from_orient
	  if rid?
	    ActiveOrient::Model.autoload_object self
	  else
	    self
	  end
  end
  alias :reload! from_orient

  def to_orient
    self.gsub /%/, '(percent)'
  end

  def rid?
    self =~ /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
  end

  def to_classname
    if self[0] == '$'
      self[1..-1]
    else
      self
    end
  end

  def to_or
    "'#{self}'"
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
