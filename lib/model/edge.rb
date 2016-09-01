# to do 
# instead of creating a class, use a module which is included on startup
# then, after specifying the namespace and before autoaccolating the database-classes create the proper E-Base-class and include this stuff
class E  < ActiveOrient::Model
  ## link to the library-class
  class << self
=begin
establish contrains on Edges

Edges are uniq!

Creates individual indices for child-classes if applied to the class itself.
=end
  def  uniq_index
    create_property  :in,  type: :link, linked_class: :V
    create_property  :out, type: :link, linked_class: :V
    create_index "#{self.name}_idx", on: [ :in, :out ]
  end
=begin
  Instantiate a new Edge between two Vertices 

  The parameters »from« **or** »to« can take a list of model-records. Then subsequent edges are created.

  :call-seq:
  Model.create from:, to:,  attributes:{}
=end


  def create  **keyword_arguments
    new_edge = db.create_edge self, **keyword_arguments
    new_edge =  new_edge.pop if new_edge.is_a?( Array) && new_edge.size == 1
    # vertices must be reloaded

    new_edge # returns the created edge (or an array of created edges
  end

  # to do
  # def delete
  # delete an edge (as class method) 
  # and 
  # def remove
  # delete an edge (as instance method)
  #
  def delete where: attributes
    puts "work in progress"
  end
  
  # remove works on record-level
  end 
  def remove
    db.delete_edge self
  end
end
