require 'nypl_ruby_util'

require_relative 'lib/location_client'
require_relative 'lib/record_manager'

def init
    return if $initialized

    $logger = NYPLRubyUtil::NyplLogFormatter.new($stdout, level: ENV['LOG_LEVEL'])
    $kms_client = NYPLRubyUtil::KmsClient.new
    $in_avro_client = NYPLRubyUtil::NYPLAvro.by_name(ENV['IN_SCHEMA_TYPE'])
    $kinesis_client = NYPLRubyUtil::KinesisClient.new({
        schema_string: ENV['OUT_SCHEMA_TYPE'],
        stream_name: ENV['KINESIS_STREAM'],
        partition_key: 'id'
    })
    $location_client = LocationClient.new

    $logger.debug 'Initialized function'
    $initialized = true
end

# rubocop:disable Lint/UnusedMethodArgument
def handle_event(event:, context:)
    init

    $logger.info 'Beginning processing of record batch'

    event['Records'].each do |record|
        $logger.debug 'Processing record from Kinesis'
        begin
            valid_record = validate_record record
        rescue HoldingParserError => e
            $logger.error("Unable to validate record with reason: #{e.message}")
            next
        end

        record_manager = RecordManager.new valid_record
        record_manager.parse_record

        begin
            send_record_to_stream valid_record
        rescue HoldingParserError => e
            $logger.error("Unable to send record to kinesis with reason: #{e.message}")
            next
        end
        $logger.debug "Processed and sent record # #{valid_record['id']} to kinesis"
    end

    $logger.info 'Processing Complete'
end
# rubocop:enable Lint/UnusedMethodArgument

def validate_record(record)
    $logger.debug 'Validating Record'
    begin
        avro_data = record['kinesis']['data']
    rescue KeyError, NoMethodError => e
        $logger.error "Missing field in Kinesis message, unable to process #{e.message}"
        raise HoldingParserError, 'Unable to process incoming Kinesis record'
    end

    begin
        decoded = $in_avro_client.decode avro_data
        $logger.debug 'Decoded bib', decoded
    rescue AvroError => e
        $logger.error "Record failed Avro decoding for reason: #{e.message}"
        raise HoldingParserError, 'Incoming kinesis record failed Avro decoding'
    end

    decoded
end

def send_record_to_stream(record)
    $kinesis_client << record
    $logger.info "Sent record to kinesis stream record ##{record['id']}"
rescue AvroError => e
    $logger.warn "Record (id# #{record['id']} failed avro validation", { status: e.message }
    raise HoldingParserError, 'Unable to encode Avro record for Kinesis'
rescue NYPLError => e
    $logger.warn "Record (id# #{record['id']} failed to write to kinesis", { status: e.message }
    raise HoldingParserError, 'Failed to send encoded record to Kinesis stream'
end

class HoldingParserError < StandardError; end
