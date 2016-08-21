# deletes the working database and recreates it 
# reassignes ORD and DB
def reset_database
  db =  ActiveOrient.database

  ORD.database_classes.reverse.each do | klass_name |
    klass =  ActiveOrient::Model.orientdb_class name: klass_name
    klass.delete_class  rescue nil
  end
  ORD.delete_database database: db
  Object.send :remove_const, :ORD 
  Object.send :remove_const, :DB
  ActiveOrient.database =  db
  Object.send :const_set, :ORD, ActiveOrient::OrientDB.new( preallocate: true )
  if OrientDB::UsingJava
    Object.send :const_set, :DB,  ActiveOrient::API.new( preallocate: false)
  else
    Object.send :const_set,  :DB, ActiveOrient::OrientDB.new( preallocate: true )
  end
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

