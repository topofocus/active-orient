require_relative "rest_private.rb" # manage private functions
require_relative "rest_read.rb" # manage get
require_relative "rest_create.rb" # manage create
require_relative "rest_change.rb" # manage update
require_relative "rest_operations.rb" # manage count, functions and execute
require_relative "rest_delete.rb" # manage delete
require 'cgi'
require 'rest-client'
require 'active_support/core_ext/string' # provides blank?, present?, presence etc

module ActiveOrient

=begin
OrientDB performs queries to a OrientDB-Database
The communication is based on the ActiveOrient-API.
The OrientDB-Server is specified in config/connect.yml
A Sample:
 :orientdb:
   :server: localhost
     :port: 2480
   :database: working-database
   :admin:
     :user: admin-user
     :pass: admin-password
=end

  class OrientDB
    include OrientSupport::Support
    include RestPrivate
    include RestRead
    include RestCreate
    include RestChange
    include RestOperations
    include RestDelete

    mattr_accessor :logger # borrowed from active_support
    mattr_accessor :default_server
    attr_reader :database # Used to read the working database

    #### INITIALIZATION ####

=begin
  Contructor: OrientDB is conventionally initialized.
  Thus several instances pointing to the same or different databases can coexist

  A simple
   xyz =  ActiveOrient::OrientDB.new
  uses the database specified in the yaml-file »config/connect.yml« and connects
   xyz = ActiveOrient::OrientDB.new database: my_fency_database
  accesses the database »my_fency_database«. The database is created if its not existing.

  *USECASE*
   xyz =  ActiveOrient::Model.orientdb = ActiveOrient::OrientDB.new
  initialises the Database-Connection and publishes the Instance to any ActiveOrient::Model-Object
=end

    def initialize database: nil, connect: true
      self.logger = Logger.new('/dev/stdout') unless logger.present?
      self.default_server = {
        :server => 'localhost',
        :port => 2480,
        :protocol => 'http',
        :user => 'root',
        :password => 'root',
        :database => 'temp'
      }.merge default_server.presence || {}
      @res = get_resource
      @database = database || default_server[:database]
      connect() if connect
      @classes = get_database_classes
      ActiveOrient::Model.orientdb = self
    end

# Used for the connection on the server

    def get_resource
      login = [default_server[:user].to_s , default_server[:password].to_s]
      server_adress = "#{default_server[:protocol]}://#{default_server[:server]}:#{default_server[:port]}"
      RestClient::Resource.new(server_adress, *login)
    end

# Used to connect to the database

    def connect
      first_tentative = true
      begin
        logger.progname = 'OrientDB#Connect'
        r = @res["/connect/#{@database}"].get
        if r.code == 204
  	      logger.info{"Connected to database #{@database}"}
  	      true
  	    else
  	      logger.error{"Connection to database #{@database} could NOT be established"}
  	      nil
  	    end
      rescue RestClient::Unauthorized => e
        if first_tentative
  	      logger.info{"Database #{@database} NOT present --> creating"}
  	      first_tentative = false
  	      create_database
  	      retry
        else
  	      Kernel.exit
        end
      end
    end

  end
end
