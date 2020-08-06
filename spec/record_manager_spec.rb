require_relative '../lib/record_manager'
require_relative './handler_spec'

describe RecordManager do
    before(:each) {
        @test_manager = RecordManager.new({ 'id' => 1 })
    }

    describe '#initialize' do
        it 'should set the initialized record as a variable' do
            expect(@test_manager.instance_variable_get(:@record)['id']).to eq(1)
        end
    end

    describe '#parse_record' do
        it 'should invoke parsers for locations and holdings' do
            @test_manager.stubs(:_parse_location).once
            @test_manager.stubs(:_parse_holdings).once

            @test_manager.parse_record
        end
    end

    describe '#_parse_location' do
        it 'should set a location object to the current record' do
            @test_manager.instance_variable_get(:@record)['fixedFields'] = {
                '40' => { 'value' => 'tst' }
            }

            $location_client.stubs(:lookup_code).once.returns({
                'code' => 'tst', 'label' => 'test location'
            })

            @test_manager.send(:_parse_location)

            expect(@test_manager.instance_variable_get(:@record)['location']['label']).to eq('test location')
        end

        it 'should return nil if no location object could be located' do
            @test_manager.instance_variable_get(:@record)['fixedFields'] = {
                '40' => { 'value' => 'none' }
            }

            $location_client.stubs(:lookup_code).once.returns(nil)

            @test_manager.send(:_parse_location)

            expect(@test_manager.instance_variable_get(:@record)['location']).to be_nil
        end
    end

    describe '#_parse_holdings' do
        it 'should set a holdings array' do
            @test_manager.send(:_parse_holdings)
            expect(@test_manager.instance_variable_get(:@record)['holdings']).to eq([])
        end
    end
end