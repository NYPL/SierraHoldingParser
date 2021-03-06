require 'json'
require 'net/http'
require 'uri'

# Class for retrieving location labels from NYPL-Core and adding them to fetched location codes
class LocationClient
    def initialize
        @locations = _load_locations
    end

    def lookup_code(code)
        location = nil
        unless code.strip == 'none'
            code_record = @locations[code.strip]

            unless code_record && code_record['code'] && code_record['label']
                raise NYPLLocationError, "Missing or incomplete code_record: #{code_record} for location code: #{code}"
            end

            location = { 'code' => code_record['code'], 'label' => code_record['label'] }
        end

        location
    end

    private

    def _load_locations
        begin
            location_jsonld_uri = URI(ENV['LOCATIONS_JSONLD_URL'])
            response = Net::HTTP.get_response(location_jsonld_uri)
        rescue StandardError => e
            $logger.error "Unable to fetch locations JSONLD due to #{e.message}"
            raise NYPLLocationError, 'Unable to load NYPL locations data'
        end

        unless response.code.to_i == 200
            $logger.error 'Received non-200 status from locations JSONLD object'
            $logger.debug 'NYPL Location error', { error: response.body }
            raise NYPLLocationError, "NYPL location fetch returned #{response.code}"
        end

        locations_object = JSON.parse(response.body)
        $logger.debug 'Loaded NYPL locations object'

        locations_object
    end
end

class NYPLLocationError < StandardError; end
