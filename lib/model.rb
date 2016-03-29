require_relative "model_class.rb"
require_relative "model_record.rb"

module ActiveOrient
  class Model < ActiveOrient::Base

    include BaseProperties
    include ModelRecord # For objects
    extend ModelClass # For classes

=begin
  ActiveOrient::Model.autoload_object "#00:00"
  either retrieves the object from the rid_store or loads it from the DB
  The rid_store is updated!
  To_do: fetch for version in the db and load the object if a change is detected
  Note: This function is not in ModelClass since I need to use @@rid_store
=end

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
    
    # Used to read the metadata
    attr_reader :metadata
  end
end
