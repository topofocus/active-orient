require "model_class.rb"
require "model_record.rb"

module ActiveOrient
  class Model < ActiveOrient::Base

    include BaseProperties
    include ModelRecord
    extend ModelClass

    def self.autoload_object rid
      if rid.rid?
        @@rid_store[rid].presence || orientdb.get_record(rid)
      else
        logger.progname = "ActiveOrient::Model#AutoloadObject"
        logger.info{"#{rid} is not a valid rid."}
      end
    end

    mattr_accessor :orientdb
    mattr_accessor :logger
  end
end
