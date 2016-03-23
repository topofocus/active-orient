require "rest_private.rb" # manage private functions
require "rest_read.rb" # manage get
require "rest_create.rb" # manage create
require "rest_change.rb" # manage update
require "rest_operations.rb" # manage count, functions and execute
require "rest_delete.rb" # manage delete

module ActiveOrient
  require 'cgi'
  require 'rest-client'
  require 'active_support/core_ext/string'

  class OrientDB
    include OrientSupport::Support
    include RestPrivate
    include RestRead
    include RestCreate
    include RestChange
    include RestOperations
    include RestDelete

    mattr_accessor :logger
    mattr_accessor :default_server
    attr_reader :database

    def initialize database: nil, connect: true
      self.logger = Logger.new('/dev/stdout') unless logger.present?
      logger.progname = 'OrientDB#Initialize'
      if database.nil?
        logger.error{"Specify a database"}
      else
        self.default_server = {
          :server => 'localhost',
          :port => 2480,
          :protocol => 'http',
    			:user => 'root',
          :password => 'root'
        }.merge default_server
        @res = get_resource
        @database = database
        connect() if connect
        @classes = []
        ActiveOrient::Model.orientdb = self
      end
    end

    def get_resource
      login = [default_server[:user].to_s , default_server[:password].to_s]
      server_adress = "#{default_server[:protocol]}://#{default_server[:server]}:#{default_server[:port]}"
      RestClient::Resource.new(server_adress, *login)
    end

    def connect
      first_tentative = true
      begin
        logger.progname = 'OrientDB#Connect'
        r= @res["/connect/#{@database}"].get
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
