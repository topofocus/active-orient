module REST

require 'base'
require 'base_properties'

class Model < REST::Base
   include BaseProperties

   def self.orientdb_class name: 
        
     klass = Class.new( self )
     name =  name.camelize
     if self.send :const_defined?, name 
       puts "Class already defined ... skipping"
       retrieved_class =  self.send :const_get, name
     else
     
	new_class = self.send :const_set  , name.capitalize , klass
	new_class.define_property :cluster, nil
	new_class.define_property :version, nil
	new_class.define_property :record, nil
	new_class # return_value
     end
   end

   # hard-coded orientdb-columns
    prop :cluster, :version, :record
  
   def default_attributes
     super.merge cluster: 0
     super.merge version: 0
     super.merge record: 0
   end
  
   def orientdb= arg
     @orientdb = arg
   end

   def self.dynamic response_hash
     response_hash.each do | key, value |
       unless attributes.keys.include? key?
	 self.class.define_property key
       end
     end

   end

#      if response_hash.['@type'] == 'd'  # document
#	new_class_name = response_hash.delete '@class'
#	rid = response_hash.delete '@rid'
#	cluster, record = rid[1,rid.size].split(':')
#	version = response_hash.delete '@version'
#
#	klass = Class.new( self )
#	new_class = self.send :const_set  , new_class_name , klass
#        
#
#	response_hash.each do | key, value |
#	  new_class.define_property 'ztr', nil
#	end
#
#   end
end # class

class Query < REST::Model

#   include BasePropertiesa

#   prop :query  # holds the query-sequence, either as string or as array

   has_many :records
   has_many :queries

   def reset_records
     self.records= []
   end
   alias reset_results reset_records

   def reset_querys
     self.queries = []
   end
=begin
calls REST::Rest#GetDocuments
stores the query in the query-stack and saves the result in the record-Array

returns the count of assigned records
=end

   def get_documents o_class: , where:  
     if @orientdb.is_a? REST::OrientDB

       count= 0
       @orientdb.get_documents( o_class: o_class , where: where ){| q| self.queries << q }.each{|c| records << c; count+=1 }
       count
   end
   end
=begin
All predefined query are send to the database.
The result is stored in the records.
The Records are of Tyoe REST::Model::Myquery
=end
   def execute_queries reset: true, transaction: true
     reset_records if reset

     @orientdb.execute( transaction: transaction) do 
     result = queries.map do |q|
       sql_cmd = -> (command) { { type: "cmd", language: "sql", command: command } }
       case q
       when String
	 sql_cmd[ q ]
       when Hash
	 q
	else
	  nil
       end # case
     end.compact 
     # save the result in records
     result.compact.each{|y| records << y if true }

     end # block
   end # def  execute_queries

end # class

end # module
