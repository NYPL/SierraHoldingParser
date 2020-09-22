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