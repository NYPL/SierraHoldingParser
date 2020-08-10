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
        _get_h_fields

        # TODO Incorporate Check-In Card data to this object
    end

    def _get_h_fields
        $logger.debug "Getting values for all h values"
        all_h_fields = @record['varFields'].filter { |f| f['fieldTag'] == 'h' }
        y_853_fields = @record['varFields'].filter { |f| f['marcTag'] == '853' && f['fieldTag'] == 'y' }

        h_866_fields = all_h_fields.filter { |f| f['marcTag'] == '866' }
        h_legacy_fields = all_h_fields.filter { |f| f['content'] != nil }
        h_863_fields = all_h_fields.filter { |f| f['marcTag'] == '863' }

        @record['holdings'].push(*_create_holding_obj(h_866_fields.map { |h| h['subfields'][0]['content'] }))
        @record['holdings'].push(*_create_holding_obj(h_legacy_fields.map { |h| h['content'] }))
        @record['holdings'].push(*_create_holding_obj(_parse_853_863_fields(y_853_fields, h_863_fields)))

        $logger.debug @record['holdings']
    end

    def _create_holding_obj holding_arr
        holding_arr.map do |h|
            {
                "holding_string" => h,
                "holding_ranges" => [],
                "index" => false,
                "incomplete" => false,
                "negation" => false
            }
        end
    end

    def _parse_853_863_fields y_fields, h_fields
        y_map = _transform_field_array_to_hash y_fields
        h_map = _transform_field_array_to_hash h_fields

        h_y_crosswalk = y_map.keys.map { |k| [k, Array.new]}.to_h

        h_map.each { |k, v|
            y_match, position = k.split('.')
            h_y_crosswalk[y_match][position.to_i - 1] = v
        }

        out_strings = Array.new
        h_y_crosswalk.each { |k, v|
            field_strings = v.map { |h|
                field_parser = ParsedField.new(h, y_map[k])
                field_parser.generate_string_representation

                field_parser.string_rep
            }
            out_strings << field_strings.join('; ')
        }

        out_strings
    end

    def _transform_field_array_to_hash fields
        fields.map { |f|
           sub_map = f['subfields'].map { |s| [s['tag'], s['content']] }.to_h 

           [sub_map['8'], sub_map.keep_if { |k, v| k != "8" }]
        }.to_h
    end
end


class ParsedField
    attr_reader :string_rep

    @@enumeration_codes = "abcdef"
    @@chronology_codes = "ijkl"

    def initialize(h_field, y_field)
        @h_field = h_field
        @y_field = y_field
        @string_rep = ''
    end

    def generate_string_representation
        enumeration = _generate_enumeration
        chronology = _generate_chronology
        @string_rep += enumeration.length > 0 ? enumeration : ''
        if chronology.length > 0
            chronology = enumeration.length > 0 ? " (#{chronology})" : chronology
            @string_rep += chronology
        end
    end

    private

    def _generate_enumeration
        @@enumeration_codes.split('').map { |c| @h_field.include?(c) ? "#{@y_field[c]} #{@h_field[c]}" : nil }.compact.join(', ')
    end

    def _generate_chronology
        date_component = DateComponent.new
        components = @@chronology_codes.split('').map do |c|
            if @h_field.include? c 
                date_component.set_field(@y_field[c].tr('()', ''), @h_field[c])
            end
        end

        date_component.create_str

        date_component.date_str
    end

    class DateComponent
        attr_reader :date_str

        @@dash_regex = /(?:[\-]{2,}|[\-]$)/

        def initialize
            @start_year = nil
            @end_year = nil
            @start_month = nil
            @end_month = nil
            @start_day = nil
            @end_day = nil

            @date_str = ''
        end

        def set_field(component, value) 
            value_arr = value.split('-')
            self.instance_variable_set("@start_#{component}", value_arr[0])
            self.instance_variable_set("@end_#{component}", value_arr[1] ? value_arr[1] : value_arr[0])
        end

        def create_str
            start_str = "#{@start_year}-#{@start_month}-#{@start_day}".gsub(@@dash_regex, '')
            end_str = "#{@end_year}-#{@end_month}-#{@end_day}".gsub(@@dash_regex, '')

            if start_str == end_str
                @date_str = start_str
            else
                @date_str = "#{start_str}/#{end_str}"
            end
        end
    end
end