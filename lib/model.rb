module REST

#require 'base'
#require 'base_properties'

class Model < REST::Base
   include BaseProperties

   mattr_accessor :orientdb
   mattr_accessor :logger

   def self.orientdb_class name: 
       #logger.progname =  "REST::Model#orientdb_class" 
     klass = Class.new( self )
     name =  name.camelize
     if self.send :const_defined?, name 
      # logger.debug { "Class  #{name} already defined ... skipping" }
       retrieved_class =  self.send :const_get, name
     else
     
	new_class = self.send :const_set  , name.capitalize , klass
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
   def riid
       [ @metadata[ :cluster ] , @metadata[ :record ] ]
   end
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
Queries the database and fetches the count of datasets
=end
   def self.count_documents where: {}
     orientdb.count_documents( o_class: self , where: where)
   end
=begin
Creates a new document with the applied attributes
and returns the freshly instantiated Object
=end

   def self.new_document attributes: {}
      orientdb.create_or_update_document o_class: self, set: attributes
   end
=begin
Create a Property in the Schema of the Class
=end

   def self.create_property field:, type: 'string', linked_class: nil
     orientdb.create_property o_class: self, field: field, type: type, linked_class: linked_class 
   end
=begin
Only if the Class inherents from »E« 
Instantiate a new Edge betwen to Vertices

Parameter: unique: (true)  In case of an existing Edge just update its Properties. 

=end
   def self.create_edge from: , to: , unique: false, attributes:{} 
      
      orientdb.nexus_edge o_class: self, attributes: attributes, from: from, to: to, unique: unique
   end
=begin
Performs a query on the Class and returns an Array of REST:Model-Records.

=end
def self.where attributes: {}
  orientdb.get_documents o_class: self, where: attributes
end
=begin

removes the Model-Instance from the database

returns true (successfully deleted) or false  ( obj not deleted)
=end
   def delete
     
     r= if is_edge?
       # returns the count of deleted edges
       orientdb.delete_edge rid
     else
      orientdb.delete_document  rid
     end
     REST::Base.remove_riid self if r # removes the obj from the rid_store
     r # true or false 
   end

   def is_edge?
     attributes.keys.include?( 'in') && attributes.keys.include?('out')
   end
   # get enables loading of datasets if a link is followed
   #  model_class.all.first.link.get
   def self.get rid
     orientdb.get_document rid
   end
   def self.all
     orientdb.get_documents( o_class: self)
   end
=begin
Convient update of the dataset by calling sql-patch
The attributes are saved to the database.
With the optional :set argument ad-hoc attributes can be defined
  obj = REST::Model::Contracts.first
  obj.name =  'new_name'
  obj.update set: { yesterdays_event: 35 }
=end
   def update  set: {}
      attributes.merge! set
     result= orientdb.patch_document(rid) do
       attributes.merge( { '@version' => @metadata[ :version ], '@class' => @metadata[ :class ] } )
     end
#     returns a new instance of REST::Model
     REST::Model.orientdb_class(name: classname).new  JSON.parse( result )

   end

=begin
Convient method for updating a embedded-type-property
its called via
  model.update_embedded(  property, value )

to query embedded elements: 
  select from {class} where {val{class} in({embedded_property}}.{embedded_property})
=end
   def update_embedded item, value
     logger.progname = 'REST::Model#UpdateEmbedded'
     orientdb.execute do
       [ {type: "cmd", language: "sql", command: "update #{link} add #{item} = #{value}"}]
     end
     self.attributes[item] = Array.new unless attributes[item].present?
     self.attributes[item] << value

   rescue RestClient::InternalServerError => e
     logger.error  "update_embedded : something went wrong"
     logger.error e.inspect
   end

=begin
Convient method for updating a linkset-property
its called via
  model.update_linkset(  linkset-property, Object_to_be_linked_to )
=end
   def update_linkset  item, link_class
     logger.progname = 'REST::Model#UpdateLinkset'
     orientdb.execute do
       [ {type: "cmd", language: "sql", command: "update #{link} add #{item} = #{link_class.link}"}]
     end
     self.attributes[item] = Array.new unless attributes[item].present?
     self.attributes[item] << link_class

   rescue RestClient::InternalServerError => e
     logger.error " Duplicate found (#{link_class.link})"
     logger.error e.inspect
   end

end # class

end # module
