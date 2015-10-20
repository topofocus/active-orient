require 'spec_helper'

describe OrientSupport::Connection do
  before( :all ) do
    @connect = OrientSupport::Messages::Outgoing::RequestConnect.new  username: 'hctw', password: 'hc'

end
  context 'Connect to Server' do
    it "call initialize" do
      expect(@orient_connection ).to be_a OrientSupport::Connection
      puts @orient_connection.to_human
      # extract the server-version
      expect( @orient_connection.to_human.split(':').last).to eq OrientSupport::VERSION.to_s
      expect( @orient_connection.socket ).to be_a OrientSupport::AOSocket
    end
    it "try manual connect" , focus: true do
    @orient_connection = OrientSupport::Connection.new   user: 'hctw', password: 'hc' , connect: false
#      puts @connect.encode.inspect
      @orient_connection.connect


      


    end
  end
end
