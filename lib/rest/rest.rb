require_relative "read.rb" # manage get
require_relative "create.rb" # manage create
require_relative "change.rb" # manage update
require_relative "operations.rb" # manage count, functions and execute
require_relative "delete.rb" # manage delete
require 'cgi'
require 'rest-client'

module ActiveOrient

=begin
OrientDB points to an OrientDB-Database.
The communication is based on the OrientDB-REST-API.

The OrientDB-Server is specified in *config/connect.yml*

A Sample:
 :orientdb:
   :server: localhost
     :port: 2480
   :database: working-database
   :admin:
     :user: admin-user
     :pass: admin-password

The connection is then established through
  ActiveOrient::OrientDB.new


By default, _config/boot.rb_  handles the connection. There this is mapped to the constant ORD. 

=end

  class OrientDB
    include OrientSupport::Support
    include OrientDbPrivate
    include DatabaseUtils
    include ClassUtils
    include RestRead
    include RestCreate
    include RestChange
    include RestOperations
    include RestDelete

    mattr_accessor :logger # borrowed from active_support

    #### INITIALIZATION ####

=begin
OrientDB is conventionally initialized.

Several instances share ActiveOrient.database and ActiveOrient.database_classes.

A simple
   xyz =  ActiveOrient::OrientDB.new

uses the database specified in the yaml-file »config/connect.yml« and connects

   zxy = ActiveOrient::OrientDB.new database: my_fency_database

accesses the database »my_fency_database«. The database is created if its not existing.

*USECASE*
   xyz =  ActiveOrient::Model.orientdb = ActiveOrient::OrientDB.new

initialises the Database-Connection and publishes the Instance to any ActiveOrient::Model-Object
=end

    def initialize database: nil, connect: true, preallocate: true, model_dir: nil
      self.logger = Logger.new('/dev/stdout') unless logger.present?
    #  self.default_server = {
    #    :server => 'localhost',
    #    :port => 2480,
    #    :protocol => 'http',
    #    :user => 'root',
    #    :password => 'root',
    #    :database => 'temp'
    #  }.merge default_server.presence || {}
    #  @res = get_resource
      ActiveOrient.database ||= database
      ActiveOrient.database_classes ||=   Hash.new
      @res = get_resource
      connect() if connect
      database_classes # initialize @classes-array and ActiveOrient.database_classes 
			ActiveOrient::Base.logger =  logger
      ActiveOrient::Model.orientdb = self 
      ActiveOrient::Model.db = self 
      ActiveOrient::Model.keep_models_without_file ||= nil
      preallocate_classes( model_dir )  if preallocate

    end

    def get_resource
      login = [ActiveOrient.default_server[:user].to_s , ActiveOrient.default_server[:password].to_s]
      server_adress = "http://#{ActiveOrient.default_server[:server]}:#{ActiveOrient.default_server[:port]}"
      RestClient::Resource.new(server_adress, *login)
    end

# Used to connect to the database

    def connect
      first_tentative = true
      begin
	database =  ActiveOrient.database
        logger.progname = 'OrientDB#Connect'
        r = @res["/connect/#{database}"].get
        if r.code == 204
  	      logger.info{"Connected to database #{database}"}
  	      true
  	    else
  	      logger.error{"Connection to database #{database} could NOT be established"}
  	      nil
  	    end
      rescue RestClient::Unauthorized => e
        if first_tentative
  	      logger.info{"Database #{database} NOT present --> creating"}
  	      first_tentative = false
  	      create_database database: database
  	      retry
        else
  	      Kernel.exit
        end
      end
    end

  end
end
