require_relative "read.rb" # manage get
require_relative "create.rb" # manage create
require_relative "change.rb" # manage update
require_relative "operations.rb" # manage count, functions and execute
require_relative "delete.rb" # manage delete
require_relative "../support/logging"
#require 'cgi'
require 'rest-client'
require 'pond'

module ActiveOrient

=begin
OrientDB points to an OrientDB-Database.
The communication is based on the OrientDB-REST-API.

Its usually initialised through ActiveOrient::Init.connect

=end

  class OrientDB
    include OrientSupport::Support
    include OrientSupport::Logging
    include OrientDbPrivate
    include DatabaseUtils
    include ClassUtils
    include RestRead
    include RestCreate
    include RestChange
    include RestOperations
    include RestDelete


    #### INITIALIZATION ####

=begin
OrientDB is conventionally initialized.


The first call initialises database-name and -classes, server-adress and user-credentials.

Subsequent initialisations are made to initialise namespaced database classes, ie.

	ORD =  ActiveOrient.init.connect  database: 'temp'
																server:  'localhost',
																port:    2480,
																user:   root, 
																password: root 
	module HC; end
	ActiveOrient::Init.define_namespace { HC }
	ActiveOrient::OrientDB.new  preallocate: true 





=end

    def initialize database: nil, preallocate: true, model_dir: nil, **defaults
      ActiveOrient.database ||= database || 'temp'
      ActiveOrient.database_classes ||=   Hash.new

			ActiveOrient.default_server ||= { :server => defaults[:server] || 'localhost' ,
																				:port   => defaults[:port] ||= 2480,
																				:user   => defaults[:user].to_s ,
																				:password => defaults[:password].to_s }
			# setup connection pool
			ActiveOrient.db_pool ||= Pond.new( :maximum_size => 15000, :timeout => 500) {  get_resource }
#			ActiveOrient.db_pool.collection = :stack
      connect() 
      database_classes # initialize @classes-array and ActiveOrient.database_classes 
			ActiveOrient::Base.logger =  logger
      ActiveOrient::Model.orientdb = self 
      ActiveOrient::Model.db = self 
      ActiveOrient::Model.keep_models_without_file ||= nil
      preallocate_classes( model_dir )  if preallocate
			Thread.abort_on_exception = true
    end

		# thread safe method to allocate a resource
    def get_resource
			logger.info {"ALLOCATING NEW RESOURCE --> #{ ActiveOrient.db_pool.size }" }
      login = [ActiveOrient.default_server[:user] , ActiveOrient.default_server[:password]]
      server_adress = "http://#{ActiveOrient.default_server[:server]}:#{ActiveOrient.default_server[:port]}"
			 RestClient::Resource.new(server_adress, *login)
    end



# Used to connect to the database

		def connect 
			first_tentative = true
			begin
				database =  ActiveOrient.database
				logger.progname = 'OrientDB#Connect'
				r = ActiveOrient.db_pool.checkout do | conn |
					r = conn["/connect/#{database}"].get
				end
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
