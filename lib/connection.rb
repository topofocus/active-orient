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
  ##		      place_order, modify_order, cancel_order
  ## public data-queue: received,  received?, wait_for, clear_received
  ## misc:	      reader_running? 


  #  mattr_accessor :current
    mattr_accessor :logger  ## borrowed from active_support
    # Please note, we are realizing only the most current Server protocol versions,
    # thus improving performance at the expense of backwards compatibility.



    attr_accessor  :socket #   Socket to  server 
    attr_accessor  :client_id 

    #def initialize opts = {}
    def initialize host: '127.0.0.1',
                   port: '2424', 
                   connect: true, # Connect at initialization
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
	instance_variable_set("@#{k}", v) unless v.nil?
      end
    end
      @connected = false
      open() if connect
  #    Connection.current = self
    end

    ### Working with connection
    def to_human
      msg=  "Host/Port: #{@host}:#{@port} \nUser:#{@user}\nServerVersion:#{@server}"
      if @connected
	msg
      else
	nil
      end
    end

    def connect
      logger.progname='Connection#connect' 
      logger.error { "Already connected!"} if connected?


      @socket = AOSocket.open(@host, @port)

      @server = @socket.read_short
      if @server_version < @server
	logger.info { "Server version #{@server} available, compatibatility.modus  #{@server_version} used." }
      end
      if @server_version > @server
	logger.fatal { "Server version #{@server_version} not supported. Max ServerVersion: #{@server}" }
	Kernel.exit
      end


      @connected = true
      logger.info { "Connected to  OrientDB server, ver: #{@server_version} "}

      request_connect
      #start_reader 
      #request_open_database if not @database.blank?
    end
    alias open connect # Legacy alias

    def request_connect
      connect = OrientSupport::Messages::Outgoing::RequestConnect.new  user: @user, password: @password
      puts connect.encode.inspect
      @socket.write_data connect.encode.pack(connect.serialize)
      status =  @socket.read_byte
      puts "Status: #{status}"
      session_id  = @socket.read_int
      @session_id  = @socket.read_int
      puts "session_id: #{@session_id.inspect}"
      @tocken = @socket.read_string
      puts "Tocken: #{@tocken.inspect}"
      
  
    end


    def request_open_database

    end

    def disconnect
      if reader_running?
        @reader_running = false
        @reader_thread.join
      end
      if connected?
        @socket.close
        @connected = false
      end
    end

    alias close disconnect # Legacy alias

    def connected?
      @connected
    end

    ### Working with message subscribers

    # Subscribe Proc or block to specific type(s) of incoming message events.
    # Listener will be called later with received message instance as its argument.
    # Returns subscriber id to allow unsubscribing
    def subscribe *args, &block
      @subscribe_lock.synchronize do
        subscriber = args.last.respond_to?(:call) ? args.pop : block
        id = random_id

        error  "Need subscriber proc or block ", :args  unless subscriber.is_a? Proc

        args.each do |what|
          message_classes =
          case
          when what.is_a?(Class) && what < Messages::Incoming::AbstractMessage
            [what]
          when what.is_a?(Symbol)
            [Messages::Incoming.const_get(what)]
          when what.is_a?(Regexp)
            Messages::Incoming::Classes.values.find_all { |klass| klass.to_s =~ what }
          else
            error  "#{what} must represent incoming IB message class", :args 
          end
     # @subscribers_lock.synchronize do
          message_classes.flatten.each do |message_class|
            # TODO: Fix: RuntimeError: can't add a new key into hash during iteration
            subscribers[message_class][id] = subscriber
          end
     # end  # lock
        end

        id
      end
    end

    # Remove all subscribers with specific subscriber id
    def unsubscribe *ids
      @subscribe_lock.synchronize do
	ids.collect do |id|
	  removed_at_id = subscribers.map { |_, subscribers| subscribers.delete id }.compact
	  logger.error  "No subscribers with id #{id}"   if removed_at_id.empty?
	  removed_at_id # return_value
	end.flatten
      end
    end
    ### Working with received messages Hash

    # Clear received messages Hash
    def clear_received *message_types
      @receive_lock.synchronize do
        if message_types.empty?
          received.each { |message_type, container| container.clear }
        else
          message_types.each { |message_type| received[message_type].clear }
        end
      end
    end

    # Hash of received messages, keyed by message type
    def received
      @received_hash ||= Hash.new { |hash, message_type| hash[message_type] = Array.new }
    end

    # Check if messages of given type were received at_least n times
    def received? message_type, times=1
      @receive_lock.synchronize do
        received[message_type].size >= times
      end
    end


    # Wait for specific condition(s) - given as callable/block, or
    # message type(s) - given as Symbol or [Symbol, times] pair.
    # Timeout after given time or 1 second.
    def wait_for *args, &block
      timeout = args.find { |arg| arg.is_a? Numeric } # extract timeout from args
      end_time = Time.now + (timeout || 1) # default timeout 1 sec
      conditions = args.delete_if { |arg| arg.is_a? Numeric }.push(block).compact

      until end_time < Time.now || satisfied?(*conditions)
        if @reader
          sleep 0.05
        else
          process_messages 50
        end
      end
    end

    ### Working with Incoming messages 


    def reader_running?
      @reader_running && @reader_thread && @reader_thread.alive?
    end

    # Process incoming messages during *poll_time* (200) msecs, nonblocking
    def process_messages poll_time = 200 # in msec
      time_out = Time.now + poll_time/1000.0
      while (time_left = time_out - Time.now) > 0
        # If socket is readable, process single incoming message
        process_message if select [@socket], nil, nil, time_left
      end
    end


    ### Sending Outgoing messages to IB

    # Send an outgoing message.
    def send_message what, *args
      message =
      case
      when what.is_a?(Messages::Outgoing::AbstractMessage)
        what
      when what.is_a?(Class) && what < Messages::Outgoing::AbstractMessage
        what.new *args
      when what.is_a?(Symbol)
        Messages::Outgoing.const_get(what).new *args
      else
        error "Only able to send outgoing messages", :args
      end
      logger.error  { "Not able to send messages, not connected!" } unless connected?
      @message_lock.synchronize do
      message.send_to @socket
      end
    end

    alias dispatch send_message # Legacy alias



    protected
    # Message subscribers. Key is the message class to listen for.
    # Value is a Hash of subscriber Procs, keyed by their subscription id.
    # All subscriber Procs will be called with the message instance
    # as an argument when a message of that type is received.
    def subscribers
      @subscribers ||= Hash.new { |hash, subs| hash[subs] = Hash.new }
    end

    # Process single incoming message (blocking!)
    def process_message
      logger.progname='OrientSupport::Connection#process_message' 
#      status = @socket.read_short # This read blocks!
      session_id = @socket.read_long # This read blocks!
      token = @socket.read_string
      request =  0 ### hier muss die abzufragende Message adressiert werden


      # Debug:
      logger.debug { "Got message #{msg_id} (#{Messages::Incoming::Classes[msg_id]})"}

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

    # Check if all given conditions are satisfied
    def satisfied? *conditions
      !conditions.empty? &&
      conditions.inject(true) do |result, condition|
        result && if condition.is_a?(Symbol)
        received?(condition)
        elsif condition.is_a?(Array)
          received?(*condition)
        elsif condition.respond_to?(:call)
          condition.call
        else
          logger.error { "Unknown wait condition #{condition}" }
        end
      end
    end
  end # class Connection
end # module IB
