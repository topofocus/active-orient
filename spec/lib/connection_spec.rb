require 'spec_helper'

describe OrientSupport::Connection do
  before( :all ) do
#    @connect = OrientSupport::Messages::Outgoing::RequestConnect.new  username: 'hctw', password: 'hc'
      @orient_connection = OrientSupport::Connection.new   user: 'hctw', password: 'hc' , database: 'First' # 'hc_database'

end
  context 'Connect to Server' do
    it "call initialize" do
      expect(@orient_connection ).to be_a OrientSupport::Connection
      puts @orient_connection.to_human
      # extract the server-version
      expect( @orient_connection.to_human.split(':').last).to eq OrientSupport::VERSION.to_s
      expect( @orient_connection.socket ).to be_a OrientSupport::AOSocket
    end
    it "try manual connect"  do
      expect( @orient_connection.socket ).to be_a TCPSocket
      @orient_connection.wait_for( :RequestDBOpen ) do |message_object|
	expect( message_object.data[:clusters] ).to be_a Hash
	# every Database has a class named _studio
	['ouser','ofunction','orole','oschedule','orids','_studio'].each do | systemclass |
	  expect( message_object.data[:clusters][systemclass] ).to be_a Numeric
	end  
      end  # wait_for

    end    # it
  end	   # context
end	   # describe
