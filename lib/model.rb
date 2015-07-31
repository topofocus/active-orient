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
     name =  name.to_s.camelize
     if self.send :const_defined?, name 
      # logger.debug { "Class  #{name} already defined ... skipping" }
       retrieved_class =  self.send :const_get, name
     else
     
	new_class = self.send :const_set  , name , klass
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
#     puts "autoload_object #{link}"
     link_cluster_and_record = link[1,link.size].split(':').map &:to_i
     @@rid_store[link_cluster_and_record].presence || orientdb.get_document( link ) 
   end

  
  def self.superClass
    orientdb.get_classes( 'name', 'superClass').detect{|x| x["name"].downcase ==  new.class.to_s.downcase.split(':')[-1].to_s
    }['superClass']
  end
=begin
Returns just the name of the Class 
=end
   def classname
      self.class.to_s.split(':')[-1]
   end

=begin
If a Rest::Model-Object is included in a HashWidhtIndifferentAccess-Object, only the link is stored
=end
     def nested_under_indifferent_access # :nodoc:
                link
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
     orientdb.count_documents( self , where: where)
   end
=begin
Creates a new Instance of the Class with the applied attributes
and returns the freshly instantiated Object
=end

   def self.create attributes = {}
      orientdb.create_or_update_document  self, set: attributes
   end

   # historic method
   def self.new_document attributes: {}  # :nodoc:
      orientdb.create_or_update_document  self, set: attributes
   end
=begin
Create a Property in the Schema of the Class
 :call-seq: 
  self.create_property  field (required) , type: 'string', linked_class: nil
=end

   def self.create_property field, **keyword_arguments 
     orientdb.create_property  self, field,  **keyword_arguments 
   end

   def self.create_link name, class_name
     orientdb.create_property self,  name, type: 'link', linked_class: class_name
   end
   def self.create_linkset name, class_name
     orientdb.create_property self,  name, type: 'linkset', linked_class: class_name
   end
=begin
Only if the Class inherents from »E« 
Instantiate a new Edge betwen two Vertices

Parameter: unique: (true)  In case of an existing Edge just update its Properties. 
 :call-seq: 
  self.create_edge from: , to: , unique: false, attributes:{} 
=end
   def self.create_edge **keyword_arguments 
      o=orientdb.nexus_edge  self, **keyword_arguments 
      [:from,:to].each{|y| keyword_arguments[y].reload! }
      o  # return_value
   end
=begin
Performs a query on the Class and returns an Array of REST:Model-Records.

Example:
  Log =  r.open_class 'Log'
  Log.where priority: 'high'
  --> submited database-request: query/hc_database/sql/select from Log where priority = 'high'/-1
  => [ #<REST::Model::Log:0x0000000480f7d8 @metadata={ ... },  ... ]


=end
def self.where attributes =  {}
  orientdb.get_documents  self, where: attributes
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
     orientdb.get_documents self
end
   def self.first
     orientdb.get_documents(  self, limit: 1).pop
   end

   def self.last
     #  debug:: orientdb.get_documents( self, order: { "@rid" => 'desc' }, limit: 1 ){ |x| puts x }.pop
     orientdb.get_documents( self, order: { "@rid" => 'desc' }, limit: 1 ).pop
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
     #REST::Model.orientdb_class(name: classname).new(  JSON.parse( result ))  # instantiate object and update rid_store
     reload!
   end
=begin
Overwrite the attributes with Database-Contents
=end
   def reload! 
     updated_dataset = orientdb.get_document( link)
     @metadata[:version]= updated_dataset.version
     attributes = updated_dataset.attributes
     self  # return_value  (otherwise only the attributes would be returned)
   end

   def remove_item_from_property array, item=nil
     logger.progname = 'REST::Model#RemoveItemFromProperty'
     execute_array =  Array.new
     return unless attributes.has_key? array
     remove_execute_array = -> (it) do
       case it
       when REST::Model
	 execute_array <<  {type: "cmd", language: "sql", command: "update #{link} remove #{array} = #{it.link}"} 
       when String
	  execute_array <<  {type: "cmd", language: "sql", command: "update #{link} remove #{array} = '#{it}'"} 
       when Numeric
	  execute_array <<  {type: "cmd", language: "sql", command: "update #{link} remove #{array} = #{it}"} 
       else
	 logger.error { "Only Basic Formats supported . Cannot Serialize #{it.class} this way" }
	 logger.error { "Try to load the array from the DB, modify it and update the hole record" }
       end
     end

     if block_given?
       items =  yield
       items.each{|x| remove_execute_array[x];   self.attributes[array].delete( x ) }
     elsif item.present?
       remove_execute_array[item]
       a= attributes; a.delete item
       self.attributes[array].delete( item )
     end
     puts "execute_array => #{execute_array}"
#    puts "attributes: #{attributes.inspect}"
     orientdb.execute do
       execute_array
     end
     reload!
    #puts "attributes: #{attributes.inspect}"
     

   rescue RestClient::InternalServerError => e
     logger.error " Could not remove item in #{array} "
     logger.error e.inspect
   end

=begin
Convient method for populating embedded- or linkset-properties

In both cases an array/ a collection is stored in the database.

its called via
  model.add_item_to_property( linkset- or embedded property, Object_to_be_linked_to )
or
  mode.add_items_to_property( linkset- or embedded property ) do
      Array_of_Objects_to_be_linked_to
      (actually, the objects must inherent from REST::Model, Numeric, String)
  end

  to_do:  use "<<" to add the item to the property
=end
   def add_item_to_property array, item=nil
     logger.progname = 'REST::Model#AddItem2Property'
     execute_array =  Array.new
     self.attributes[array] = Array.new unless attributes[array].present?
     add_2_execute_array = -> (it) do
       case it
       when REST::Model
	 execute_array <<  {type: "cmd", language: "sql", command: "update #{link} add #{array} = #{it.link}"} 
       when String
	  execute_array <<  {type: "cmd", language: "sql", command: "update #{link} add #{array} = '#{it}'"} 
       when Numeric
	  execute_array <<  {type: "cmd", language: "sql", command: "update #{link} add #{array} = #{it}"} 
       else
	 logger.error { "Only Basic Formats supported . Cannot Serialize #{it.class} this way" }
	 logger.error { "Try to load the array from the DB, modify it and update the hole record" }
       end
     end

     if block_given?
       items =  yield
       items.each{|x| add_2_execute_array[x];   self.attributes[array] << x }
     elsif item.present?
       add_2_execute_array[item]
       self.attributes[array] << item
     end
     orientdb.execute do
       execute_array
     end
     reload!

   rescue RestClient::InternalServerError => e
     logger.error " Duplicate found in #{array} "
     logger.error e.inspect
   end

   alias add_items_to_property add_item_to_property
   ## historical aliases
   alias update_linkset  add_item_to_property
   alias update_embedded  add_item_to_property
=begin
Convient method for updating a linkset-property
its called via
  model.update_linkset( linkset-property, Object_to_be_linked_to )
or
  mode.update_linkset( linkset-property ) do
      Array_of_Objects_to_be_linked_to
  end
=end

#private 
   def version
     @metadata[ :version ] 
   end

end # class

end # module
