 shared_examples_for 'basic class properties' do |bez|
     
     it "class #{bez}: initialize and add a property " do 
      ORD.delete_class bez 
      subject = ORD.create_class bez
puts "subject:  #{subject.inspect}"
puts "superclass: #{subject.superclass}"
puts "ref name: #{subject.ref_name}"
      subject.create_property :test_ind, type: 'string' 

      expect( subject.get_properties[:properties] ).to have(1).item 
     end
 end


