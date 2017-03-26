# deletes the working database and recreates it 
# reassignes ORD and DB


=begin
 Create a new Instance to the Database given in ActiveOrient.database
 and assign it to ORD and DB
=end
def initialize_database 
  Object.send :const_set, :ORD, ActiveOrient::OrientDB.new( preallocate: false )
  if OrientDB::UsingJava
    Object.send :const_set, :DB,  ActiveOrient::API.new( preallocate: false )
  else
    Object.send :const_set,  :DB, ORD #  ActiveOrient::OrientDB.new( preallocate: true )
  end

end

=begin
Deletes the active database and unallocates ORD and DB
=end
def destroy_database
  unless defined?(ORD) == 'constant' 
    Object.send :const_set, :ORD,     ActiveOrient::OrientDB.new(  preallocate:  false)
  end  
  ORD.delete_database database: ActiveOrient.database
  ActiveOrient::Model.allocated_classes = {}
  Object.send :remove_const, :ORD 
  Object.send( :remove_const, :DB ) if defined?(DB) == 'constant'

end

=begin
Delete the temp-database,
initialize classes using etl (spec/etl/*.json)
and initialize orientDB without reading the database-classes (this will be tested!)
=end
def read_etl_data
  ### TODO:: change to custom paths  
  ActiveOrient.database = 'temp'
  destroy_database

  ###     CHANGE CUSTOM PATHS
  ###	  absolute path to the spec-etl-dir                       place to etl-bin of orientdb
  Dir[ "/home/topo/activeorient/spec/etl/*json" ].each{| f | `cd /opt/orientdb/bin; ./oetl.sh #{f} ` }

  ActiveOrient.database = 'temp'
  ActiveOrient::Model.keep_models_without_file = nil
  initialize_database

end
def reset_database
  db =  ActiveOrient.database
  destroy_database
  initialize_database

end


 shared_examples_for 'correct allocated classes' do |input|
   it "has allocated all classes" do
    case input
    when Array
      input.each{|y| expect( ORD.database_classes ).to include ORD.classname(y) }
      expect( classes ).to have( input.size ).items
    when Hash
    else  
      expect( classes ).to be_kind_of ActiveOrient::Model

    end
   end

 end

