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
      rid = rid[1..-1] if rid[0]=='#'
      if rid.rid?
	if  @@rid_store[rid].present?
	  @@rid_store[rid]  
	else
	   db.get_record(rid)
	end
      else
        logger.progname = "ActiveOrient::Model#AutoloadObject"
        logger.info{"#{rid} is not a valid rid."}
      end
    end

    ## to prevent errors when calling to_a 
    def to_ary
      attributes.to_a
    end

=begin
Deletes the database class and removes the ruby-class 
=end
    def self.delete_class
      orientdb.delete_class self
      ActiveOrient::Model.send(:remove_const, naming_convention.to_sym)
    end

    # provides an unique accessor on the Class
    # works with a class-variable, its unique through all Subclasses
    mattr_accessor :orientdb  # points to the instance of the REST-DB-Client used for Administration
			      # i.e. creation and deleting of classes and databases
    mattr_accessor :db	      # points to the instance of the Client used for Database-Queries
    mattr_accessor :api
    mattr_accessor :logger
#    mattr_accessor  :ref_name    
    # Used to read the metadata
    attr_reader :metadata

    # provides an accessor at class level 
    # it unique on all instances 
      class << self
	    attr_accessor :ref_name
	    attr_accessor :abstract
      end
  end
end
