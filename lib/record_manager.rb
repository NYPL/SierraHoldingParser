require_relative './field_parser'

# Class that performs the main transformation functions, including
# - Fetching Check-In Card data
# - Fetching location labels
# - Parsing holding objects
class RecordManager
    @@default_y_fields = {
        'a' => '',
        'b' => '',
        'c' => '',
        'd' => '',
        'e' => '',
        'f' => '',
        'i' => 'year',
        'j' => 'month',
        'k' => 'day',
        'l' => ''
    }

    def initialize(record)
        @record = record
    end

    def self.default_y_fields
        @@default_y_fields
    end

    def parse_record
        $logger.info "Parsing record # #{@record['id']}"

        # If record is deleted, don't modify it at all:
        if @record['deleted']
            $logger.debug 'Passing deleted record through as is'
            return
        end

        _parse_location
        _parse_holdings
    end

    private

    def _parse_location
        $logger.debug 'Adding location object to record'

        location_object = $location_client.lookup_code @record['fixedFields']['40']['value']
        $logger.debug 'Retrieved location object', location_object || { message: 'No location specified' }

        @record['location'] = location_object
    end

    def _parse_holdings
        $logger.debug 'Setting parsed holdings field'
        @record['holdings'] = []

        # Extract all holdings strings into the holdings field
        _get_h_fields

        # Incorporate Check-In Card data to this object
        _get_check_in_card
    end

    def _get_check_in_card
        $logger.debug "Fetching check-in card data for holding ##{@record['id']}"

        begin
            check_in_card_uri = URI(
                "#{ENV['PLATFORM_API_BASE_URL']}holdings/check-in-cards?holding_id=#{@record['id']}"
            )
            response = Net::HTTP.get_response(check_in_card_uri)
        rescue StandardError => e
            $logger.error 'Failed to load check-in card data', { status: e.message }
            raise RecordError, 'Could not load check-in-card data'
        end

        # Confirm that a valid response was received
        unless response.code.to_i == 200
            $logger.error "Unable to load check-in card data with status #{response.code}", { status: response.body }
            raise RecordError, "Unable to load check-in card data with status #{response.code}"
        end

        # Parse response into an object
        check_in_data = JSON.parse(response.body)
        $logger.debug check_in_data
        @record['checkInCards'] = check_in_data
    end

    def _get_h_fields
        $logger.debug 'Getting values for all h values'

        y_853_fields = @record['varFields'].filter { |f| f['marcTag'] == '853' && f['fieldTag'] == 'y' }

        h_866_fields, h_legacy_fields, h_863_fields = _load_h_fields_by_type

        @record['holdings'].push(*_create_holding_obj(h_866_fields.map { |h| h['subfields'][0]['content'] }))
        @record['holdings'].push(*_create_holding_obj(h_legacy_fields.map { |h| h['content'] }))
        @record['holdings'].push(*_create_holding_obj(_parse_853_863_fields(y_853_fields, h_863_fields)))

        $logger.debug @record['holdings']
    end

    def _load_h_fields_by_type
        all_h_fields = @record['varFields'].filter { |f| f['fieldTag'] == 'h' }

        h_866_fields = all_h_fields.filter { |f| f['marcTag'] == '866' }
        h_legacy_fields = all_h_fields.filter { |f| !f['content'].nil? }
        h_863_fields = all_h_fields.filter { |f| f['marcTag'] == '863' }

        [h_866_fields, h_legacy_fields, h_863_fields]
    end

    def _create_holding_obj(holding_arr)
        holding_arr.map do |h|
            {
                'holding_string' => h,
                'holding_ranges' => [],
                'index' => false,
                'incomplete' => false,
                'negation' => false
            }
        end
    end

    def _parse_853_863_fields(y_fields, h_fields)
        y_map = y_fields.empty? ? { '1' => @@default_y_fields } : _transform_field_array_to_hash(y_fields)
        h_map = _transform_field_array_to_hash h_fields

        h_y_crosswalk = y_map.keys.map { |k| [k, []] }.to_h

        h_map.each do |k, v|
            y_match, position = k.split('.')
            h_y_crosswalk[y_match][position.to_i - 1] = v
        end

        out_strings = []
        h_y_crosswalk.each do |k, v|
            out_strings << v.map do |h|
                next if h.nil?

                field_parser = ParsedField.new(h, y_map[k])
                field_parser.generate_string_representation

                field_parser.string_rep
            end.compact.join('; ')
        end

        out_strings
    end

    def _transform_field_array_to_hash(fields)
        fields.map do |f|
            sub_map = f['subfields'].map { |s| [s['tag'], s['content']] }.to_h

            [sub_map['8'], sub_map.keep_if { |k, _v| k != '8' }]
        end.to_h
    end
end

class RecordError < StandardError; end
