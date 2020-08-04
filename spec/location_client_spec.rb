require 'json'
require 'uri'

require_relative '../lib/location_client'
require_relative './spec_helper'

describe LocationClient do
    describe '#_load_locations' do
        it 'should set an object of locations from JSONLD source' do
            mock_data = JSON.dump({
                'tst' => {
                    :code => 'tst',
                    :label => 'test location'
                }
            })
            mock_response = mock()
            mock_response.stubs(:code).returns('200')
            mock_response.stubs(:body).returns(mock_data)
            Net::HTTP.stubs(:get_response).once.with(URI('test_jsonld_url')).returns(mock_response)

            test_client = LocationClient.new

            expect(test_client.instance_variable_get(:@locations)['tst']['label']).to eq('test location')
        end

        it 'should raise an error if it is unable to get a response from the JSONLD object' do
            Net::HTTP.stubs(:get_response).once.with(URI('test_jsonld_url')).raises(StandardError.new('test error'))

            expect { LocationClient.send(:new) }.to raise_error(NYPLLocationError, "Unable to load NYPL locations data")
        end

        it 'should raise an error if the method receives a non-200 response code' do
            mock_response = mock()
            mock_response.stubs(:code).returns('500')
            mock_response.stubs(:body).returns('test error')
            Net::HTTP.stubs(:get_response).once.with(URI('test_jsonld_url')).returns(mock_response)

            expect { LocationClient.send(:new) }.to raise_error(NYPLLocationError, "NYPL location fetch returned 500")
        end
    end

    describe '#lookup_code' do
        before(:each) {
            mock_resp = mock()
            mock_resp.stubs(:code).returns('200')
            mock_resp.stubs(:body).returns(JSON.dump({
                :tst => { :code => 'tst', :label => 'test location' }
            }))
            Net::HTTP.stubs(:get_response).once.returns(mock_resp)
            @test_client = LocationClient.new
        }

        it 'should return a location object if code is found' do
            out_object = @test_client.lookup_code 'tst'

            expect(out_object['label']).to eq('test location')
        end

        it 'should return nil if the location code is none' do
            out_object = @test_client.lookup_code 'none '

            expect(out_object).to eq(nil)
        end
    end
end