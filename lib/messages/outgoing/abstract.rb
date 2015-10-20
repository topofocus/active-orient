
module OrientSupport
  module Messages
    module Outgoing
       extend Messages # def_message macros
       



      # Container for specific message classes, keyed by their message_ids
      Classes = {}

      class AbstractMessage < OrientSupport::Messages::AbstractMessage

        def initialize session_id:-1, **data
	  @session_id =  session_id
          @data = data
        end
        # This causes the message to send itself over the server socket in server[:socket].
        # "server" is the @server instance variable from the IB object.
        # You can also use this to e.g. get the server version number.
        #
        # Subclasses can either override this method for precise control over how
        # stuff gets sent to the server, or else define a method encode() that returns
        # an Array of elements that ought to be sent to the server by calling to_s on
        # each one and postpending a '\0'.
        #
        def send_to socket
	  
          self.encode.to_soc do |data|
	     socket.write_data data
	  end
        end

	def serialize
	  "cl>" << self.class.data_map.map{|name,format,default| AOSocket.socket_format(data_or_default(name,default), format) }.join
	end

	def data_or_default field, default_value=''
	  @data[field].present?? @data[field] : default_value
	end

 
        # Same message representation as logged by TWS into API messages log file
        def to_s
          self.encode.map{ |x| x.to_s }.join('-')
        end


        # Pre-process encoded message Array before sending into socket, such as
        # changing booleans into 0/1 and stuff
        def preprocess
          self.encode.map {|data| data == true ? 1 : data == false ? 0 : data }
        end

        # Encode message content into (possibly, nested) Array of values.
        # At minimum, encoded Outgoing message contains message_id and version.
        # Most messages also contain (ticker, request or order) :id.
        # Then, content of @data Hash is encoded per instructions in data_map.
        # This method may be modified by message subclasses!
        def encode
          [self.class.message_id,
           @session_id.presence || -1,
           self.class.data_map.map do |(field, format, default_value)|
	      data_or_default( field, default_value ).to_soc
	   end
	  ].flatten
	     
          #ä   case
          #ä   when default_method.nil?
          #ä     @data[field]

          #ä   when default_method.is_a?(Symbol) # method name with args
          #ä     @data[field].send default_method, *args

          #ä   when default_method.respond_to?(:call) # callable with args
          #ä     default_method.call @data[field], *args

          #ä   else # default
          #ä     @data[field].nil? ? default_method : @data[field] # may be false still
          #ä   end
          #ä end
          #ä ]
          # TWS wants to receive booleans as 1 or 0
        end

      end # AbstractMessage
    end # module Outgoing
  end # module Messages
end
