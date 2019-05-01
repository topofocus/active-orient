class String
	def ex_rid
		sub /#[0-9]*:[0-9]*/, '*'
	end
end


 shared_examples_for 'basic class properties' do |bez|
     
     it "class #{bez}: initialize and add a property " do 
      @db.delete_class bez 
      subject = @db.create_class bez
puts "subject:  #{subject.inspect}"
puts "superclass: #{subject.superclass}"
puts "ref name: #{subject.ref_name}"
      subject.create_property :test_ind, type: 'string' 

      expect( subject.get_properties[:properties] ).to have(1).item 
     end
 end
shared_examples_for 'a valid record' do
  it{ is_expected.to be_an ActiveOrient::Model }
#	its( :created_at ) { is_expected.to be_a DateTime }
	its( :metadata ) { is_expected.to be_a Hash }
	its( :attributes ) { is_expected.to be_a Hash }
	its( :rid ){ is_expected.to match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/ }


end

shared_examples_for 'a new record' do
	its( :version ){ is_expected.to eq 1 }
	it_behaves_like 'a valid record'
	
end

