class String
  def to_or
    "'#{self}'"
  end
end

class Numeric
  def to_or
   "#{self.to_s}"  
  end
end
module REST

#require 'base'
#require 'base_properties'

class Model < REST::Base
   include BaseProperties

   mattr_accessor :orientdb
   mattr_accessor :logger
=begin
orientdb_class is used to instantiate a REST:Model:{class} by providing its name
todo: implement object-inherence
=end
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
REST::Model.autoload_object "#00:00"
either retrieves the object from the rid_store or loads it from the DB

the rid_store is updated!

to_do: fetch for version in the db and load the object if a change is detected
=end
   def self.autoload_object   link
     link_cluster_and_record = link[1,link.size].split(':').map &:to_i
     @@rid_store[link_cluster_and_record].presence || orientdb.get_document( link ) 
   end

  def self.superClass
    puts new.classname
    orientdb.get_classes( 'name', 'superClass').detect{|x| x["name"] == new.classname}['superClass']
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
   def riid # :nodoc:
       [ @metadata[ :cluster ] , @metadata[ :record ] ]
   end
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


=begin 
Queries the database and fetches the count of datasets
=end
   def self.count where: {}
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
 :call-seq: 
  self.create_property  field: (required) , type: 'string', linked_class: nil
=end

   def self.create_property **keyword_arguments 
     orientdb.create_property o_class: self, **keyword_arguments 
   end
=begin
Only if the Class inherents from »E« 
Instantiate a new Edge betwen two Vertices

Parameter: unique: (true)  In case of an existing Edge just update its Properties. 
 :call-seq: 
  self.create_edge from: , to: , unique: false, attributes:{} 
=end
   def self.create_edge **keyword_arguments 
     puts "key: #{keyword_arguments}" 
      orientdb.nexus_edge o_class: self, **keyword_arguments 
      [:from,:to].each{|y| keyword_arguments[y].reload }
   end
=begin
Performs a query on the Class and returns an Array of REST:Model-Records.

=end
def self.where attributes =  {}
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
=begin
An Edge is defined 
* when inherented from the superclass »E» (formal definition)
* if it has an in- and an out property 

Actually we just check the second term as we trust the constuctor to work properly
=end
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
   def self.first
     orientdb.get_documents( o_class: self, limit: 1).pop
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
     REST::Model.orientdb_class(name: classname).new(  JSON.parse( result ))  # instantiate object and update rid_store
     reload!
   end

   def reload! updated_dataset=nil
    # puts "link: #{rid}"
     updated_dataset = orientdb.get_document( link)
     @metadata[:version]= updated_dataset.version
     attributes = updated_dataset.attributes
     self  # return_value  (otherwise only the attributes would be returned)
   end
=begin
Convient method for updating a embedded-type-property
its called via
  model.update_embedded(  property, value )
or
  model.update_embedded( property) do
    Array_of_Values_to_be_embedded
  end
to query embedded elements: 
  select from {class} where {val{class} in({embedded_property}}.{embedded_property})
=end
   def update_embedded item, value=nil
     logger.progname = 'REST::Model#UpdateEmbedded'
     execute_array =  Array.new
     self.attributes[item] = Array.new unless attributes[item].present?
     add_2_execute_array = -> (v){ execute_array <<  {type: "cmd", language: "sql", command: "update #{link} add #{item} = #{v.to_or}"} }
     if block_given?
       values =  yield
       values.each{|x| add_2_execute_array[x]; self.attributes[item] << x }
     elsif value.present?
       add_2_execute_array[value]
       self.attributes[item] << value
     end
     puts execute_array.inspect

     orientdb.execute do
       execute_array
     end
     reload!

   rescue RestClient::InternalServerError => e
     logger.error  "update_embedded : something went wrong"
     logger.error e.inspect
   end

=begin
Convient method for updating a linkset-property
its called via
  model.update_linkset( linkset-property, Object_to_be_linked_to )
or
  mode.update_linkset( linkset-property ) do
      Array_of_Objects_to_be_linked_to
  end
=end
   def update_linkset  item, link_class=nil 
     logger.progname = 'REST::Model#UpdateLinkset'
     execute_array =  Array.new
     self.attributes[item] = Array.new unless attributes[item].present?
     add_2_execute_array = -> (lc){ execute_array << {type: "cmd", language: "sql", command: "update #{link} add #{item} = #{lc.link}"} }
     if block_given?
       link_classes =  yield
       link_classes.each{|x| add_2_execute_array[x];  self.attributes[item] << x }
     elsif link_class.present?
       add_2_execute_array[link_class]
       self.attributes[item] << link_class
     end
     orientdb.execute do
       execute_array
     end
     reload!

   rescue RestClient::InternalServerError => e
     logger.error " Duplicate found (#{link_class.link})"
     logger.error e.inspect
   end

#private 
   def version
     @metadata[ :version ] 
   end

end # class

end # module
