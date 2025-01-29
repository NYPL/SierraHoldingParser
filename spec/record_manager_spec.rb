require_relative '../lib/record_manager'
require_relative './spec_helper'

TEST_VARFIELDS = {
    'holdings' => [],
    'varFields' => [
        {
            'fieldTag' => 'h',
            'content' => 'test holding 1'
        },
        {
            'fieldTag' => 'h',
            'marcTag' => '866',
            'subfields' => [
                {
                    'content' => 'test holding 2'
                }
            ]
        },
        {
            'fieldTag' => 'h',
            'marcTag' => '863',
            'subfields' => [
                {
                    'tag' => '8',
                    'content' => '1.1'
                },
                {
                    'tag' => 'a',
                    'content' => 'test holding 3'
                }
            ]
        },
        {
            'fieldTag' => 'y',
            'marcTag' => '853',
            'subfields' => [
                {
                    'tag' => '8',
                    'content' => '1'
                },
                {
                    'tag' => 'a',
                    'content' => 'test field'
                }
            ]
        }
    ]
}.freeze

describe RecordManager do
    before(:each) {
        $location_client = mock

        @test_manager = RecordManager.new({ 'id' => 1 })
    }

    describe :initialize do
        it 'should set the initialized record as a variable' do
            expect(@test_manager.instance_variable_get(:@record)['id']).to eq(1)
        end
    end

    describe :parse_record do
        it 'should invoke parsers for locations and holdings' do
            @test_manager.stubs(:_parse_location).once
            @test_manager.stubs(:_parse_holdings).once

            @test_manager.parse_record
        end

        it 'should pass through deleted record' do
            deleted_record = { 'deleted' => true }
            deleted_record_inst = RecordManager.new(deleted_record)
            deleted_record_inst.parse_record
        end
    end

    describe :_parse_location do
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

    describe :_parse_holdings do
        it 'should set a holdings array and invoke h_field parser' do
            @test_manager.stubs(:_get_h_fields).once
            @test_manager.stubs(:_get_check_in_card).once

            @test_manager.send(:_parse_holdings)
            expect(@test_manager.instance_variable_get(:@record)['holdings']).to eq([])
        end
    end

    describe :_get_check_in_card do
        it 'should add an array for the check_in_card field on success' do
            mock_resp = mock
            mock_resp.stubs(:code).returns('200')
            mock_resp.stubs(:body).returns(JSON.dump([{ 'box_id': 1 }, { 'box_id': 2 }, { 'box_id': 3 }]))

            Net::HTTP.stubs(:get_response).returns(mock_resp)

            @test_manager.send(:_get_check_in_card)

            expect(@test_manager.instance_variable_get(:@record)['checkInCards'][1]['box_id']).to eq(2)
        end

        it 'should raise a RecordError if the status code is not 200' do
            mock_resp = mock
            mock_resp.stubs(:code).returns('400')
            mock_resp.stubs(:body).returns('Test Error Message')

            Net::HTTP.stubs(:get_response).returns(mock_resp)

            expect {
                @test_manager.send(:_get_check_in_card)
            }.to raise_error(RecordError, 'Unable to load check-in card data with status 400')
        end

        it 'should raise a RecordError if the HTTP request fails' do
            Net::HTTP.stubs(:get_response).raises(StandardError.new)

            expect {
                @test_manager.send(:_get_check_in_card)
            }.to raise_error(RecordError, 'Could not load check-in-card data')
        end
    end

    describe :_get_h_fields do
        it 'should fetch all fields with the h tag and parse the legacy, 863 and 866 fields seperately' do
            @test_manager.instance_variable_set(:@record, TEST_VARFIELDS)

            @test_manager.stubs(:_load_h_fields_by_type).once.returns(
                [
                    [{ 'subfields' => [{ 'content' => 'test holding 2' }] }],
                    [{ 'content' => 'test holding 1' }],
                    [{ 'subfields' => [{ 'content' => 'test holding 3' }] }]
                ]
            )
            @test_manager.stubs(:_create_holding_obj).once.with(['test holding 1']).returns(['test holding 1'])
            @test_manager.stubs(:_create_holding_obj).once.with(['test holding 2']).returns(['test holding 2'])
            @test_manager.stubs(:_create_holding_obj).once.with(['test holding 3']).returns(['test holding 3'])
            @test_manager.stubs(:_parse_853_863_fields).once.returns(['test holding 3'])

            @test_manager.send(:_get_h_fields)

            expect(
                @test_manager.instance_variable_get(:@record)['holdings']
            ).to eq(['test holding 2', 'test holding 1', 'test holding 3'])
        end
    end

    describe :_load_h_fields_by_type do
        it 'should filter 863, 866 and legacy fields into their own arrays' do
            @test_manager.instance_variable_set(:@record, TEST_VARFIELDS)

            test_866_arr, test_legacy_arr, test_863_arr = @test_manager.send(:_load_h_fields_by_type)
            expect(test_866_arr[0]['marcTag']).to eq('866')
            expect(test_866_arr[0]['subfields'][0]['content']).to eq('test holding 2')
            expect(test_863_arr[0]['marcTag']).to eq('863')
            expect(test_863_arr[0]['subfields'][1]['content']).to eq('test holding 3')
            expect(test_legacy_arr[0]['marcField']).to eq(nil)
            expect(test_legacy_arr[0]['content']).to eq('test holding 1')
        end
    end

    describe :_create_holding_obj do
        it 'should return an array of holdings objects for all strings passed to it' do
            out_arr = @test_manager.send(:_create_holding_obj, ['test1', 'test2'])

            expect(out_arr[0]['holding_string']).to eq('test1')
            expect(out_arr[1]['holding_string']).to eq('test2')
            expect(out_arr[0]['index']).to eq(false)
            expect(out_arr[1]['index']).to eq(false)
        end
    end

    describe :_parse_853_863_fields do
        it 'should return string representation of 863 field' do
            y_fields = [TEST_VARFIELDS['varFields'][3]]
            h_fields = [TEST_VARFIELDS['varFields'][2]]

            mock_parser = mock
            ParsedField.stubs(:new).once.with(
                { 'a' => 'test holding 3' },
                { 'a' => 'test field' }
            ).returns(mock_parser)

            mock_parser.stubs(:generate_string_representation).once
            mock_parser.stubs(:string_rep).once.returns('test holding 3')

            out_arr = @test_manager.send(:_parse_853_863_fields, y_fields, h_fields)

            expect(out_arr).to eq(['test holding 3'])
        end

        it 'should use default y/863 fields if no 863 object is present in holding record' do
            y_fields = {}
            h_fields = [TEST_VARFIELDS['varFields'][2]]

            mock_parser = mock
            ParsedField.stubs(:new).once.with(
                { 'a' => 'test holding 3' },
                RecordManager.default_y_fields 
            ).returns(mock_parser)

            mock_parser.stubs(:generate_string_representation).once
            mock_parser.stubs(:string_rep).once.returns('test holding 3')

            out_arr = @test_manager.send(:_parse_853_863_fields, y_fields, h_fields)

            expect(out_arr).to eq(['test holding 3'])
        end

        it 'should skip nil values in h field mapping and not add them to crosswalk' do
            y_fields = [TEST_VARFIELDS['varFields'][3]]
            h_fields = [TEST_VARFIELDS['varFields'][2]]
            h_fields[0]['subfields'][0]['content'] = '1.2'

            mock_parser = mock
            ParsedField.stubs(:new).once.with(
                { 'a' => 'test holding 3' },
                { 'a' => 'test field' }
            ).returns(mock_parser)

            mock_parser.stubs(:generate_string_representation).once
            mock_parser.stubs(:string_rep).once.returns('test holding 3')

            out_arr = @test_manager.send(:_parse_853_863_fields, y_fields, h_fields)

            expect(out_arr).to eq(['test holding 3'])
        end
    end

    describe :_transform_field_array_to_hash do
        it 'should set the "8" field as the hash key' do
            test_fields = [
                {
                    'subfields' => [
                        { 'tag' => '8', 'content' => '1' },
                        { 'tag' => 'a', 'content' => 'test' },
                        { 'tag' => 'b', 'content' => 'other' }
                    ]
                },
                {
                    'subfields' => [
                        { 'tag' => '8', 'content' => '2' },
                        { 'tag' => 'a', 'content' => 'test2' },
                        { 'tag' => 'b', 'content' => 'second' }
                    ]
                }
            ]

            out_hash = @test_manager.send(:_transform_field_array_to_hash, test_fields)

            expect(out_hash.keys).to eq(['1', '2'])
            expect(out_hash['1']['a']).to eq('test')
            expect(out_hash['2']['b']).to eq('second')
        end
    end
end
