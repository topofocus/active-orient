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

