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
        $logger.debug "Retrieved location #{location_object[:label]} for code #{location_object[:code]}"

        @record['location'] = location_object
    end

    def _parse_holdings
        $logger.debug "Setting parsed holdings field"
        @record['holdings'] = {}  
    end
end