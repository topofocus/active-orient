 shared_examples_for 'basic class properties' do |bez|
     
     it "class #{bez}: initialize and add a property " do 
      ORD.delete_class bez 
      subject = ORD.open_class bez

      subject.create_property :test_ind, type: 'string' 

      expect( subject.get_properties[:properties] ).to have(1).item 
     end
 end


