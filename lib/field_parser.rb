# Class for parsing and transforming holding records into strings that can be displayed in SCC
class ParsedField
    attr_reader :string_rep

    @@enumeration_codes = 'abcdef'
    @@chronology_codes = 'ijkl'
    @@date_field_mappings = {
        'day' => /\(?da(?:y|\.)?\)?/,
        'month' => /\(?mo(?:n|nth)?\.?\)?/,
        'year' => /\(?(?:yr|yea|ye)\.?\)?/
    }

    def initialize(h_field, y_field)
        @h_field = h_field
        @y_field = y_field
        @string_rep = ''
    end

    def generate_string_representation
        enumeration = _generate_enumeration
        chronology = _generate_chronology
        @string_rep += enumeration.length > 0 ? enumeration : ''

        return unless chronology.length > 0

        chronology = enumeration.length > 0 ? " (#{chronology})" : chronology
        @string_rep += chronology
    end

    private

    def _generate_enumeration
        @@enumeration_codes.split('').map do |c|
            @h_field.include?(c) && _empty_field_check(@h_field[c]) ? "#{@y_field[c]} #{@h_field[c]}" : nil
        end.compact.join(', ')
    end

    def _generate_chronology
        date_component = DateComponent.new
        @@chronology_codes.split('').map do |c|
            if @h_field.include?(c) && _empty_field_check(@h_field[c])
                date_component.set_field(_standardize_date_definition_field(@y_field[c]), @h_field[c])
            end
        end

        date_component.create_str

        date_component.date_str
    end

    def _standardize_date_definition_field(field)
        @@date_field_mappings.each do |full_name, field_test|
            return full_name if field_test.match?(field)
        end

        raise FieldParserError, "Unable to identify field #{field} for chronology"
    end

    def _empty_field_check(field)
        return true if field.strip.length > 0
    end

    # Parses date fields into a single ISO-8601 representation
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
            instance_variable_set("@start_#{component}", value_arr[0])
            instance_variable_set("@end_#{component}", value_arr[1] || value_arr[0])
        end

        def create_str
            start_str = "#{@start_year}-#{@start_month}-#{@start_day}".gsub(@@dash_regex, '')
            end_str = "#{@end_year}-#{@end_month}-#{@end_day}".gsub(@@dash_regex, '')

            @date_str = start_str == end_str ? start_str : "#{start_str}/#{end_str}"
        end
    end
end

class FieldParserError < StandardError; end
