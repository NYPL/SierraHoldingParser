# Class for parsing and transforming holding records into strings that can be displayed in SCC
class ParsedField
    attr_reader :string_rep

    @@enumeration_codes = 'abcdef'
    @@chronology_codes = 'ijkl'
    @@date_field_mappings = {
        'day' => /(?<=(?:\(|^))d(?:ay|a|)(?=(?:\.|\)|$))/,
        'month' => /(?<=(?:\(|^))m(?:onth|on|o|)(?=(?:\.|\)|$))/,
        'year' => /(?<=(?:\(|^))y(?:ear|ea|r|e|)(?=(?:\.|\)|$))/
    }

    def initialize(h_field, y_field)
        @h_field = h_field
        @y_field = y_field
        @string_rep = ''
        @continuing = false
    end

    # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    def generate_string_representation
        start_enumeration, end_enumeration = _generate_enumeration
        start_chronology, end_chronology = _generate_chronology

        string_els = [start_enumeration, start_chronology, end_enumeration, end_chronology]

        string_els[1] = " (#{start_chronology})" if start_chronology && start_enumeration

        if end_chronology && end_enumeration
            string_els[3] = " (#{end_chronology})"
        elsif end_enumeration && start_chronology
            string_els[3] = " (#{start_chronology})"
        end

        string_els.insert(2, ' - ') if end_enumeration || end_chronology

        string_els << '-' if @continuing

        @string_rep = string_els.compact.join('')
    end
    # rubocop:enable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

    private

    def _generate_enumeration
        start_enumeration_els = []
        end_enumeration_els = []
        @@enumeration_codes.split('').each do |c|
            next unless @h_field.include?(c) && _empty_field_check(@h_field[c]) ? "#{@y_field[c]} #{@h_field[c]}" : nil

            @continuing = true if @h_field[c].end_with?('-')

            value_arr = @h_field[c].strip.split('-')
            clean_y_field = @y_field[c].tr('()', '').strip

            _add_enumeration_component(start_enumeration_els, end_enumeration_els, value_arr, clean_y_field)
        end

        [
            _joined_string_or_nil(start_enumeration_els, delimiter: ''),
            _joined_string_or_nil(end_enumeration_els, delimiter: '')
        ]
    end

    def _add_enumeration_component(start_els, end_els, h_values, y_field)
        explicit_y_field = y_field.length > 0
        enum_delimiter = explicit_y_field ? ', ' : ':'

        start_els << enum_delimiter unless start_els.length == 0
        start_els << (explicit_y_field ? "#{y_field} #{h_values[0]}" : h_values[0])

        return unless h_values[1]

        end_els << enum_delimiter unless end_els.length == 0
        end_els << (explicit_y_field ? "#{y_field} #{h_values[1]}" : h_values[1])
    end

    def _joined_string_or_nil(arr, delimiter: ',')
        arr.length > 0 ? arr.join(delimiter) : nil
    end

    def _generate_chronology
        date_component = DateComponent.new
        @@chronology_codes.split('').map do |c|
            if @h_field.include?(c) && _empty_field_check(@h_field[c])
                @continuing = true if @h_field[c].end_with?('-')
                date_component.set_field(_standardize_date_definition_field(@y_field[c]), @h_field[c])
            end
        end

        date_component.create_str
    end

    def _standardize_date_definition_field(field)
        @@date_field_mappings.each do |full_name, field_test|
            return full_name if field_test.match?(field)
        end

        return nil if field == '()'

        raise FieldParserError, "Unable to identify field #{field} for chronology"
    end

    def _empty_field_check(field)
        return true if field.strip.length > 0
    end

    # Parses date fields into a single ISO-8601 representation
    class DateComponent
        @@dash_regex = /(?:[\-]{2}|[\-]$)/
        @@field_order = ['year', 'month', 'day', 'unknown']

        def initialize
            @start_year = nil
            @end_year = nil
            @start_month = nil
            @end_month = nil
            @start_day = nil
            @end_day = nil
            @start_unknown = nil
            @end_unknown = nil
        end

        def set_field(component, value)
            component = _find_next_component if component.nil?
            puts component
            value_arr = value.split('-')
            instance_variable_set("@start_#{component}", value_arr[0])
            instance_variable_set("@end_#{component}", value_arr[1] || value_arr[0])
        end

        def create_str
            start_str = "#{@start_year}-#{@start_month}-#{@start_day}-#{@start_unknown}".gsub(@@dash_regex, '')
            end_str = "#{@end_year}-#{@end_month}-#{@end_day}-#{@end_unknown}".gsub(@@dash_regex, '')

            [
                start_str.length > 0 ? start_str : nil,
                end_str.length > 0 && end_str != start_str ? end_str : nil
            ]
        end

        private

        def _find_next_component
            @@field_order.each do |f|
                return f if instance_variable_get("@start_#{f}").nil?
            end
        end
    end
end

class FieldParserError < StandardError; end
