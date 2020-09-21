require_relative '../app'
require_relative './spec_helper'

describe 'handler' do
    describe '#init' do
        before(:each) {
            $initialized = false

            @kms_mock = mock
            @kms_mock.stubs(:decrypt)
            NYPLRubyUtil::KmsClient.stubs(:new).returns(@kms_mock)
            @avro_mock = mock
            NYPLRubyUtil::NYPLAvro.stubs(:by_name).returns(@avro_mock)
            @kinesis_mock = mock
            NYPLRubyUtil::KinesisClient.stubs(:new).returns(@kinesis_mock)
            @locations_mock = mock
            LocationClient.stubs(:new).returns(@locations_mock)
        }

        after(:each) {
            @kms_mock.unstub(:decrypt)
        }

        it 'should invoke clients and logger from the ruby utils gem' do
            init

            expect($kms_client).to eq(@kms_mock)
            expect($in_avro_client).to eq(@avro_mock)
            expect($kinesis_client).to eq(@kinesis_mock)
            expect($location_client).to eq(@locations_mock)
            expect($initialized).to eq(true)
        end
    end

    describe '#handle_event' do
        before(:each) {
            @mock_manager = mock
            RecordManager.stubs(:new).returns(@mock_manager)
            @records = [{ 'id' => 1 }, { 'id' => 2 }, { 'id' => 3 }]
        }
        it 'should invoke validate_record and send_record_to_stream for each record' do
            stubs(:init).once
            stubs(:validate_record).once.with(1).returns(@records[0])
            stubs(:validate_record).once.with(2).returns(@records[1])
            stubs(:validate_record).once.with(3).returns(@records[2])
            @mock_manager.stubs(:parse_record).times(3)
            stubs(:send_record_to_stream).times(3)

            handle_event(event: { 'Records' => [1, 2, 3] }, context: {})
        end

        it 'should skip sending records to kinesis is avro validation fails' do
            stubs(:init).once
            stubs(:validate_record).once.with(1).returns(@records[0])
            stubs(:validate_record).once.with(2).raises(HoldingParserError.new)
            stubs(:validate_record).once.with(3).returns(@records[2])
            @mock_manager.stubs(:parse_record).twice
            stubs(:send_record_to_stream).once.with(@records[0])
            stubs(:send_record_to_stream).once.with(@records[2])

            handle_event(event: { 'Records' => [1, 2, 3] }, context: {})
        end

        it 'should continue processing if sending to kinesis raises an error' do
            stubs(:init).once
            stubs(:validate_record).once.with(1).returns(@records[0])
            stubs(:validate_record).once.with(2).returns(@records[1])
            stubs(:validate_record).once.with(3).returns(@records[2])
            @mock_manager.stubs(:parse_record).times(3)
            stubs(:send_record_to_stream).once.raises(HoldingParserError.new)
            stubs(:send_record_to_stream).once.with(@records[1])
            stubs(:send_record_to_stream).once.with(@records[2])

            handle_event(event: { 'Records' => [1, 2, 3] }, context: {})
        end
    end

    describe '#validate_record' do
        before(:each) {
            @mock_avro = mock
            $in_avro_client = @mock_avro
        }

        it 'should return a decoded record' do
            @mock_avro.stubs(:decode).once.with('test record').returns('decoded record')

            result = validate_record({ 'kinesis' => { 'data' => 'test record' } })
            expect(result).to eq('decoded record')
        end

        it 'should raise an error if the record is missing the kinesis data object' do
            @mock_avro.stubs(:decode).never

            expect {
                send(:validate_record, { 'other' => { 'data' => 'record' } })
            }.to raise_error(HoldingParserError, 'Unable to process incoming Kinesis record')
        end

        it 'should raise an error if the decode method fails' do
            @mock_avro.stubs(:decode).raises(AvroError.new('testing'))

            expect {
                send(:validate_record, { 'kinesis' => { 'data' => 'record' } })
            }.to raise_error(HoldingParserError, 'Incoming kinesis record failed Avro decoding')
        end
    end

    describe '#send_record_to_stream' do
        before(:each) {
            @mock_kinesis = mock
            $kinesis_client = @mock_kinesis

            @test_record = { 'id' => 1 }
        }

        it 'should encode and send record when successful' do
            @mock_kinesis.stubs(:<<).once.with(@test_record)

            send_record_to_stream(@test_record)
        end

        it 'should raise an error and not invoke kinesis if encoding fails' do
            @mock_kinesis.stubs(:<<).once.raises(AvroError.new('test'))

            expect {
                send(:send_record_to_stream, @test_record)
            }.to raise_error(HoldingParserError, 'Unable to encode Avro record for Kinesis')
        end

        it 'should raise an error if unable to send record to kinesis' do
            @mock_kinesis.stubs(:<<).once.raises(NYPLError.new('test'))

            expect {
                send(:send_record_to_stream, @test_record)
            }.to raise_error(HoldingParserError, 'Failed to send encoded record to Kinesis stream')
        end
    end
end
