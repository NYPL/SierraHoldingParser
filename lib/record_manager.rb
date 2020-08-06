class RecordManager
    def initialize record
        @record = record
    end

    def parse_record
        $logger.info "Parsing record # #{@record['id']}"
        _parse_location
        _parse_holdings
    end

    private

    def _parse_location
        $logger.debug "Adding location object to record"

        location_object = $location_client.lookup_code @record['fixedFields']['40']['value']
        $logger.debug "Retrieved location object", location_object 

        @record['location'] = location_object
    end

    def _parse_holdings
        $logger.debug "Setting parsed holdings field"
        @record['holdings'] = []

        # Extract all holdings strings into the holdings field
        # _get_h_fields

        # TODO Incorporate Check-In Card data to this object
    end

    def _get_h_fields
        $logger.debug "Getting values for all h values"
        all_h_fields = @record['varFields'].filter { |f| f['fieldTag'] == 'h' }
        y_853_fields = @record['varFields'].filter { |f| f['marcTag'] == '853' && f['fieldTag'] == 'y' }

        h_866_fields = all_h_fields.filter { |f| f['marcTag'] == '866' }
        h_legacy_fields = all_h_fields.filter! { |f| f['content'] == nil }
        h_863_fields = all_h_fields.filter { |f| f['marcTag'] == '863' }

        @record['holdings'].push(*h_866_fields.map { |h| h['subfields'][0]['content'] })
        @record['holdings'].push(*h_866_fields.map { |h| h['content'] })
        @record['holdings'].push(*_parse_853_863_fields(y_853_fields, h_863_fields))
    end

    def _parse_853_863_fields y_fields, h_fields
        y_map = y_fields.map { |y|
            sub_map = y['subfields'].map { |s| [s['tag'], s['content']] }.to_h

            [sub_map['8'], sub_map.keep_if { |k, v| k != 8 }]
        }

        h_map = h_fields.map { |h|
            sub_map = h['subfields'].map { |s| [s['tag'], s['content']] }.to_h
        }
    end

    def _transform_field_array_to_hash fields
        fields.map { |f|
            
        }
    end
end