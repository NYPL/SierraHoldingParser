require_relative '../lib/field_parser'
require_relative './handler_spec'

describe ParsedField do
    describe :initialize do
        it 'should initialize with h and y fields' do
            test_parser = ParsedField.new('h_field', 'y_field')

            expect(test_parser.instance_variable_get(:@h_field)).to eq('h_field')
            expect(test_parser.instance_variable_get(:@y_field)).to eq('y_field')
            expect(test_parser.string_rep).to eq('')
            expect(ParsedField.class_variable_get(:@@enumeration_codes)).to eq('abcdef')
            expect(ParsedField.class_variable_get(:@@chronology_codes)).to eq('ijkl')
        end
    end

    describe :generate_string_representation do
        before(:each) {
            @test_parser = ParsedField.new('h_field', 'y_field')
        }

        it 'should add enumeration to the string_rep if present' do
            @test_parser.stubs(:_generate_enumeration).once.returns('test enum')
            @test_parser.stubs(:_generate_chronology).once.returns('')

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('test enum')
        end

        it 'should add enumeration and chronology (in parens) to the string_rep if both present' do
            @test_parser.stubs(:_generate_enumeration).once.returns('test enum')
            @test_parser.stubs(:_generate_chronology).once.returns('test chron')

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('test enum (test chron)')
        end

        it 'should add chronology (sans parens) to the string_rep if no enumeration present' do
            @test_parser.stubs(:_generate_enumeration).once.returns('')
            @test_parser.stubs(:_generate_chronology).once.returns('test chron')

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('test chron')
        end
    end

    describe :_generate_enumeration do
        it 'should return comma delimited string of subfields in @@enumeration_codes' do
            test_parser = ParsedField.new(
                { 'a' => '1', 'c' => '3' },
                { 'a' => 'v.', 'b' => 'ser.', 'c' => 'iss.' }
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str).to eq('v. 1, iss. 3')
        end

        it 'should return an empty string if there are no enumeration subfields in the h record' do
            test_parser = ParsedField.new({ 'i' => '1999' }, { 'a' => 'v.' })

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str).to eq('')
        end

        it 'should return an empty string if there are no subfields in the h record' do
            test_parser = ParsedField.new({ }, { 'a' => 'v.' })

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str).to eq('')
        end

        it 'should remove any subfields if the h record is an empty string' do
            test_parser = ParsedField.new(
                { 'a' => '1', 'b' => '', 'c' => '3'},
                { 'a' => 'v.', 'b' => 'ser.', 'c' => 'i.'}
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str).to eq('v. 1, i. 3')
        end
    end

    describe :_generate_chronology do
        it 'should pass key/value pairs to DateComponent and get string from created object' do 
            test_parser = ParsedField.new(
                { 'i' => '1999', 'j' => 'Mar' },
                { 'i' => 'year', 'j' => '(month)' }
            )

            mock_date_comp = mock()
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).once.with('year', '1999')
            mock_date_comp.stubs(:set_field).once.with('month', 'Mar')
            mock_date_comp.stubs(:create_str).once
            mock_date_comp.stubs(:date_str).once.returns('1999-Mar')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('1999-Mar')
        end

        it 'should pass no fields to DateComponent if no matching subfields exist and return empty string' do 
            test_parser = ParsedField.new(
                { 'a' => '1', 'c' => '3' },
                { 'i' => 'year', 'j' => '(month)' }
            )

            mock_date_comp = mock()
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).never
            mock_date_comp.stubs(:create_str).once
            mock_date_comp.stubs(:date_str).once.returns('')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('')
        end

        it 'should omit any fields that are only an empty string' do
            test_parser = ParsedField.new(
                { 'i' => '1999', 'j' => '' },
                { 'i' => 'year', 'j' => 'month' }
            )

            mock_date_comp = mock()
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).once.with('year', '1999')
            mock_date_comp.stubs(:set_field).never
            mock_date_comp.stubs(:create_str).once
            mock_date_comp.stubs(:date_str).once.returns('1999')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('1999')
        end

        it 'should handle delimiter fields with abreviations' do
            test_parser = ParsedField.new(
                { 'i' => '1999', 'j' => '09', 'k' => '09' },
                { 'i' => '(yr.)', 'j' => 'mo.', 'k' => 'da' }
            )

            mock_date_comp = mock()
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).once.with('year', '1999')
            mock_date_comp.stubs(:set_field).once.with('month', '09')
            mock_date_comp.stubs(:set_field).once.with('day', '09')
            mock_date_comp.stubs(:create_str).once
            mock_date_comp.stubs(:date_str).once.returns('1999-09-09')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('1999-09-09')
        end
    end

    describe :_standardize_date_definition_field do
        it 'should return the full name of a date field for an abbreviation' do
            test_parser = ParsedField.new({}, {})

            out_field = test_parser.send(:_standardize_date_definition_field, '(yr.)')

            expect(out_field).to eq('year')
        end

        it 'should raise an error if the date field is not recognized' do
            test_parser = ParsedField.new({}, {})

            expect { test_parser.send(:_standardize_date_definition_field, '(smthg.)') }.to raise_error(FieldParserError, 'Unable to identify field (smthg.) for chronology')
        end
    end

    describe :_empty_field_check do
        it 'should return true if the field is not an empty string' do
            test_parser = ParsedField.new({}, {})

            expect(test_parser.send(:_empty_field_check, 'test')).to eq(true)
        end

        it 'should return false if the field is an empty string' do
            test_parser = ParsedField.new({}, {})

            expect(test_parser.send(:_empty_field_check, '   ')).to eq(nil)
        end
    end
end