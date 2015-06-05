module REST

#require 'base'
#require 'base_properties'

class Model < REST::Base
   include BaseProperties
   def self.orientdb_class name: 
       #logger.progname =  "REST::Model#orientdb_class" 
     klass = Class.new( self )
     name =  name.camelize
     if self.send :const_defined?, name 
      # logger.debug { "Class  #{name} already defined ... skipping" }
       retrieved_class =  self.send :const_get, name
     else
     
	new_class = self.send :const_set  , name.capitalize , klass
#	new_class.define_property :cluster, nil
#	new_class.define_property :version, nil
#	new_class.define_property :record, nil
#	new_class.define_property :fieldTypes, nil
	new_class.orientdb =  orientdb
	new_class # return_value
     end
   end

=begin
Returns just the name of the Class 
=end
   def classname
      self.class.to_s.split(':')[-1]
   end

     mattr_accessor :orientdb
     mattr_accessor :logger

   # hard-coded orientdb-columns
#     prop :cluster, :version, :record, :fieldtypes
  
#   def default_attributes
#     super.merge cluster: 0
#     super.merge version: 0
#     super.merge record: 0
#   end
=begin
rid is used in the where-part of sql-queries
=end
   def rid
     if @metadata.has_key?( 'cluster')
       "#{@metadata[ :cluster ]}:#{@metadata[ :record ]}"
     else
       "0:0"
     end
   end
=begin
link is used in any sql-commands 
eg .  update #link set  ...
=end
   def link
     "##{rid}"

   end

   def version
     @metadata[ :version ] 
   end

   ### currently not used
   def self.dynamic response_hash
     response_hash.each do | key, value |
       unless attributes.keys.include? key?
	 self.class.define_property key
       end
     end

   end

=begin
Convient update of the dataset by calling sql-patch
The attributes are saved to the database.
The optional :set argument 
=end
   def update  set: {}
      attributes.merge set

     orientdb.patch_document(rid) do
       attributes.merge( { '@version' => @metadata[ :version ], '@class' => @metadata[ :class ] } )
     end
   end

=begin
Convient method for updating a linkset-property
its called via
  model.update_linkset(  REST::Query.new , :property, Object that provides the link )
=end
   def update_linkset q_class, item, link_class
     q_class.queries = [ "update #{link} add #{item} = #{link_class.link}" ]
     puts q_class.queries.inspect
     q_class.execute_queries

   rescue RestClient::InternalServerError => e
     puts e.inspect
     puts "update_linkset : Duplicate found (#{link_class.link})"
   end

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

   def reset_queries
     self.queries = []
   end
=begin
calls REST::Rest#GetDocuments
stores the query in the query-stack and saves the result in the record-Array

returns the count of assigned records
=end

   def get_documents o_class: , where:  

       count= 0
       orientdb.get_documents( o_class: o_class , where: where ){| q| self.queries << q }.each{|c| records << c; count+=1 }
       count
   end
=begin
All predefined query are send to the database.
The result is stored in the records.
The Records are of Tyoe REST::Model::Myquery
=end
   def execute_queries reset: true, transaction: true
     reset_records if reset

     orientdb.execute( transaction: transaction) do 
     result = queries.map do |q|
       # command: words are seperated by one space only, thus squeeze multible spaces
       sql_cmd = -> (command) { { type: "cmd", language: "sql", command: command.squeeze(' ') } }
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
