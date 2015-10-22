require 'socket'
class TrueClass
  def to_soc
    1
  end
end

class FalseClass
  def to_soc
  0
  end
end
class  String
  def to_soc
    ss = self.size
    if size>0
    #sprintf( "%04d%s", ss, self)
    [ss,self]
    else
      '-1'
    end
  end
end

class NilClass
  def to_soc
  [-1]
  end
end
class Numeric
  def to_soc
     self
  end
end
class Array
  def to_soc 
   map( &:to_soc ).join
  end
end

# The block specifies short, int or big  (4,16,32 bit serialisation)

module OrientSupport
  class AOSocket < TCPSocket

    # Sends null terminated data string into socket
    def write_data data
#      puts data.inspect
      self.syswrite data
    end

    # returns the Charater(s) for array#pack 
    def self.socket_format data, format=nil
#      puts "data: #{data}"
      format =  data.class.to_s.downcase if format.nil?
      format =  format.to_sym unless format.is_a? Symbol
 #     puts "format: #{format}"
# http://ruby-doc.org/core-2.2.0/Array.html#method-i-pack
      case format
	when :falseclass, :trueclass
	  'c'
	when :fixnum, :int8
	  'n'
	when :int, :int16
	  'i>'
	when :long, :int32
	  'N'
	when :longlong, :int64
	  'q>'
	when :double   # float
	  'G'
	when :single
	  'g'
	when :string , :binary
	  (data.nil? || data=='') ? 'N' : 'Na'+ data.size.to_s # null padded
	else
	  puts "ERROR SOCKET.FORMAT :" + format.to_s
	  # to do : raise an Error insteed
      end
    end
    #def read_byte(n=1)
    #  a = []
    #  n.times{ a << self.getc }
    #  a
    #end

    def read_int
	self.read(4).unpack('i>').pop   # alternative: 'l' 
      end
def read_byte
      self.read(1).unpack('c').pop
    end
    def read_short
      self.read(2).unpack('s>').pop   # big endian, signed fixum from 2 byte
    end
    def read_long
	self.read(8).unpack('q').pop
    end


    def read_string
      length = read_int
      length>0 ?  self.read(length) : '' # we are just returning the contents of the stream 
    end


    def read_int_max
      str = self.read_string
      str.to_i unless str.nil? || str.empty?
    end

    def read_boolean
      str = self.read_string
      str.nil? ? false : str.to_i != 0
    end

    def read_decimal
      # Floating-point numbers shouldn't be used to store money...
      # ...but BigDecimals are too unwieldy to use in this case... maybe later
      #  self.read_string.to_d
      self.read_string.to_f
    end

    def read_decimal_max
      str = self.read_string
      # Floating-point numbers shouldn't be used to store money...
      # ...but BigDecimals are too unwieldy to use in this case... maybe later
      #  str.nil? || str.empty? ? nil : str.to_d
      str.to_f unless str.nil? || str.empty? || str.to_f > 1.797 * 10.0 ** 306
    end

    # If received decimal is below limit ("not yet computed"), return nil
    def read_decimal_limit limit = -1
      value = self.read_decimal
      # limit is the "not yet computed" indicator
      value <= limit ? nil : value
    end

    alias read_decimal_limit_1 read_decimal_limit

    def read_decimal_limit_2
      read_decimal_limit -2
    end

    ### Complex operations

    # Returns loaded Array or [] if count was 0
    def read_array &block
      count = read_int
      count > 0 ? Array.new(count, &block) : []
    end

    # Returns loaded Hash
    def read_hash
      tags = read_array { |_| [read_string, read_string] }
      tags.empty? ? Hash.new : Hash[*tags.flatten]
    end

  end # class AOSocket

end # module AcitveOrient
