require 'thread'
require 'socket'
require 'logger'

module OrientSupport 
  # Encapsulates API connection to TWS or Gateway
  class Connection

  
  ## -------------------------------------------- Interface ---------------------------------
  ## public attributes: socket, next_local_id ( alias next_order_id)
  ## public methods:  connect (alias open), disconnect, connected?
  ##		      subscribe, unsubscribe
  ##		      send_message (alias dispatch)
  ## misc:	      reader_running? 


  #  mattr_accessor :current
    mattr_accessor :logger  ## borrowed from active_support
    # Please note, we are realizing only the most current Server protocol versions,
    # thus improving performance at the expense of backwards compatibility.



    attr_accessor  :socket #   Socket to  server 
    attr_accessor  :sessions

    #def initialize opts = {}
    def initialize host: '127.0.0.1',
                   port: '2424', 
                   logger: Logger.new('/dev/stdout'),
		   user: 'guest',
		   password: 'guest' ,
		   database: nil,  # don't connect to a database by default
                   client_id: -1,
                   server_version: OrientSupport::VERSION,  # from constants.rb
		   **any_other_parameters_which_are_ignored


      # convert parameters into instance-variables and assign them
      method(__method__).parameters.each do |type, k|
	next unless type == :key
	case k
	when :logger
	  self.logger = logger  unless self.logger.is_a? Logger
	else
	  v = eval(k.to_s)
	  instance_variable_set("@#{k}", v) if v.present?
	end
      end
      @message_lock = Mutex.new
      @sessions =   Hash.new
      @message_stack =  []
      @object_stack = []
      @proc_stack = Hash.new
      @connected = false

      @socket = AOSocket.open(@host, @port)
      @server = @socket.read_short
      if server_version < @server
	logger.info { "Server version #{@server} available, compatibatility.modus  #{@server_version} used." }
      end
      if server_version > @server
	logger.fatal { "Server version #{@server_version} not supported. Max ServerVersion: #{@server}" }
	Kernel.exit
      end


      logger.info { "Connected to  OrientDB server, ver: #{@server_version} "}

      start_reader 
 #     request_connect if connect
	send_message :RequestConnect , user: @user, password: @password
	send_message :RequestDBOpen , user: @user, password: @password, database: @database if @database.present?
#      end
  #    Connection.current = self
    end

    ### Working with connection
    def to_human
        "Host/Port: #{@host}:#{@port} \nUser:#{@user}\nServerVersion:#{@server}"
    end

=begin
Close session by its number or its db
 close_session 12234  
 close_session :temp
=end

    def close_session ida
      id = ida.is_a?(Numeric) ? ida : @sessions[ida.to_s]
      if id.present? && @sessions.has_value?( id )
	send_message :RequestDBClose, session: id
      end
    end
  
    def close_sessions 
      @sessions.values.each{|x| close_session x }
      @sessions = Hash.new
    end

    def disconnect
      if reader_running?
        @reader_running = false
        @reader_thread.join
      end
      if connected?
        @socket.close
	@session = Hash.new
      end
    end

    alias close disconnect # Legacy alias

    def connected?
      @session[:db].present? || ( @database.present? && @session[@database].present? )
    end




    ### Working with Incoming messages 

    def wait_for what , timeout: 1, &b
      end_time = Time.now + timeout 
      until end_time < Time.now || processed= message_processed?(what, &b)
          sleep 0.05
      end

#      yield if block_given? && processed

      processed


    end

    def reader_running?
      @reader_running && @reader_thread && @reader_thread.alive?
    end

    # Process incoming messages during *poll_time* (200) msecs, nonblocking
    def process_messages poll_time = 20 # in msec
      time_out = Time.now + poll_time/1000.0
      while (time_left = time_out - Time.now) > 0
        # If socket is readable, process single incoming message
        process_message if select [@socket], nil, nil, time_left
      end
    end


    ### Sending Outgoing messages to IB

    # Send an outgoing message.
    def send_message what, *args, &b
      message =
      case
      when what.is_a?(Messages::Outgoing::AbstractMessage)
        what 
      when what.is_a?(Class) && what < Messages::Outgoing::AbstractMessage
        what.new *args, &b
      when what.is_a?(Symbol)
        Messages::Outgoing.const_get(what).new *args, &b
      else
        error "Only able to send outgoing messages", :args
      end
      
      logger.error  { "Not able to send messages, not connected!" } if @socket.nil?
      @message_lock.synchronize do
	@message_stack <<  message.encode.first
	message.send_to @socket
      end
    end

    alias dispatch send_message # Legacy alias



    protected

    def message_processed? what, &b
      massage_id = case 
      when what.is_a?(Class) && what < Messages::Outgoing::AbstractMessage
        what.message_id
      when what.is_a?(Symbol)
        Messages::Outgoing.const_get(what).message_id
      when what.is_a?( Numeric )
	what
      end
      mp,da=false
      @message_lock.synchronize do
	mp= @message_stack.blank? ||( @message_stack.first != what) 
	da = !@object_stack.blank? && @object_stack.first.data_available?
	yield @object_stack.last if block_given? && mp && da
      end
      mp & da
    end

    # Process single incoming message (blocking!)
    def process_message
      logger.progname='OrientSupport::Connection#process_message' 

      status =  @socket.read_byte
      if status.zero?  #  Status OK, Not Asynchronous Mode
	session_id  = @socket.read_int
	session_id  = @socket.read_int if session_id < 0 
	token = @socket.read_string
	data_cage = Messages::Incoming::Classes[@message_stack.first].new(@socket)
	# Initialize the objecta
	data_cage.read_data
	#Thread.new(data_cage){ |dc|  dc.load }.join
	# do other stuff here
	case @message_stack.first
	when 2
	  @sessions[:db] = session_id
	when 3
	  @sessions[@database] = session_id
	end
	#      puts "Token: #{token.inspect}"


	# Debug:
	logger.debug { "[#{session_id}]:: Processed #{Messages::Outgoing::Classes[@message_stack.first].to_s.split('::').last}"}
	@message_lock.synchronize do
	  @message_stack.shift  # remove Proc from message_stack
	  @object_stack << data_cage  # add Instance to object_stack
	end
      elsif status== 1
	## Error
      elsif status == 3
	## Asynchronous Mode
      end
    end
    # Start reader thread that continuously reads messages from @socket in background.
    # If you don't start reader, you should manually poll @socket for messages
    # or use #process_messages(msec) API.
    def start_reader
      Thread.abort_on_exception = true
      @reader_running = true
      @reader_thread = Thread.new do
        process_messages while @reader_running
      end
    end

    def random_id
      rand 999999999
    end

  end # class Connection
end # module IB
