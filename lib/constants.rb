   module OrientSupport
   ### Widely used  constants:
       
         EOL = "\0"

	 OK		= 0
	 ERROR 		= 1

	 SYNC		= 0
	 ASYNC		= 1
	 DRIVER_NAME 	= 'ActiveOrient'.freeze
	 DRIVER_VERSION = '0.99'

	 COMMAND_CLASS	= 'com.orientechnologies.orient.core.sql.OCommandSQL'.freeze
	 QUERY_CLASS	= 'com.orientechnologies.orient.core.sql.query.OSQLSynchQuery'.freeze

	 NEW_SESSION	= -1

	 VERSION = 30  # Minimum  ServerVersion 



  module Operations
    SHUTDOWN		  			= 1
    CONNECT					= 2
    COUNT 					= 40
    DATACLUSTER_ADD				= 10
    DATACLUSTER_DATARANGE			= 13
    DATACLUSTER_REMOVE				= 11
    DB_CLOSE					= 5
    DB_COUNTRECORDS				= 9
    DB_CREATE			  		= 4
    DB_DELETE					= 7
    DB_EXIST					= 6
    DB_OPEN					= 3
    DB_RELOAD					= 73
    DB_SIZE					= 8
    COMMAND					= 41
    RECORD_CREATE				= 31
    RECORD_DELETE				= 33
    RECORD_LOAD					= 30
    RECORD_UPDATE				= 32
    CONFIG_GET        = 70
    CONFIG_SET        = 71
    CONFIG_LIST       = 72
  end

  module RecordTypes
    RAW		= 'b'.ord
    FLAT		= 'f'.ord
    DOCUMENT 	= 'd'.ord
  end
  module PayloadStatuses
    NO_RECORDS	= 0
    RESULTSET	= 1
    PREFETCHED	= 2
    NULL		= 'n'.ord
    RECORD 		= 'r'.ord
    SERIALIZED 	= 'a'.ord
    COLLECTION	= 'l'.ord
  end

  module VersionControl
    INCREMENTAL		= -1
    NONE 		= -2
    ROLLBACK		= -3
  end
   end
