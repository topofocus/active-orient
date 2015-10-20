module OrientSupport
  module Messages

    class AbstractMessage

#      mattr_accessor :message_id
      attr_accessor  :session_id
      attr_accessor  :data

      # Class methods
      def self.data_map # Map for converting between structured message and raw data
	@data_map ||= []
      end

      def self.version # Per class, minimum message version supported
	@version || 1
      end


      def self.message_id
	@message_id || -1
      end

      # Returns message type Symbol (e.g. :OpenOrderEnd)
      def self.message_type
	to_s.split(/::/).last.to_sym
      end


      def message_type
	self.class.message_type
      end


      def to_human
#	@data={} if @data.nil?
	"<#{self.message_type}:" +
	  @data.map do |key, value|
	  unless [:version].include?(key)
	    " #{key} #{ value.is_a?(Hash) ? value.inspect : value}"
	  end
	end.compact.join(',') + " >"
      end

    end  # class AbstractMessage


    # Macro that defines short message classes using a one-liner.
    #   First arg is  message_id 
    #   data_map contains instructions for processing @data Hash. Format:
    #      Incoming messages: [field, type] or [group, field, type]
    #      Outgoing messages: field, [field, default] or [field, method, [args]]
    def def_message message_id =1 , *data_map, &to_human
      base = data_map.first.is_a?(Class) ? data_map.shift : self::AbstractMessage

      # Define new message class
      message_class = Class.new(base) do
	@message_id = message_id || -1
#	define_method( :message_id) { message_id }

	@data_map = data_map.map do |(name, *args)|
	  # Avoid redefining existing accessor methods
	    define_method(name) { @data[name] } unless instance_methods.include?(name.to_s) || instance_methods.include?(name.to_sym)
	    # first symbol becomes type, anything else goes to default
	    type, default =  args.partition{|x| x.is_a?(Symbol)}.map &:pop
	    [ name, type, default ] # content of each array-element of @data_map
	end
	define_method(:to_human, &to_human) if to_human
      end

      # Add defined message class to Classes Hash keyed by its message_id
      self::Classes[message_id] = message_class

      message_class # return_value
    end  #  def_message


  end # module messages
end  # module Orientsupport
