require_relative '../lib/field_parser'
require_relative './spec_helper'

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
            @test_parser.stubs(:_generate_enumeration).once.returns(['test enum', nil])
            @test_parser.stubs(:_generate_chronology).once.returns([nil, nil])

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('test enum')
        end

        it 'should add enumeration and chronology (in parens) to the string_rep if both present' do
            @test_parser.stubs(:_generate_enumeration).once.returns(['test enum', nil])
            @test_parser.stubs(:_generate_chronology).once.returns(['test chron', nil])

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('test enum (test chron)')
        end

        it 'should add chronology (sans parens) to the string_rep if no enumeration present' do
            @test_parser.stubs(:_generate_enumeration).once.returns([nil, nil])
            @test_parser.stubs(:_generate_chronology).once.returns(['test chron', nil])

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('test chron')
        end

        it 'should add a hyphen to the end of the string if continuing is present' do
            @test_parser.stubs(:_generate_enumeration).once.returns(['test enum', nil])
            @test_parser.stubs(:_generate_chronology).once.returns(['test chron', nil])
            @test_parser.instance_variable_set(:@continuing, true)

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('test enum (test chron)-')
        end

        it 'should create a hypher separated range for start and end enumerations' do
            @test_parser.stubs(:_generate_enumeration).once.returns(['test enum1', 'test enum2'])
            @test_parser.stubs(:_generate_chronology).once.returns([nil, nil])

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('test enum1 - test enum2')
        end

        it 'should create a hypher separated range for start and end chronologies' do
            @test_parser.stubs(:_generate_enumeration).once.returns([nil, nil])
            @test_parser.stubs(:_generate_chronology).once.returns(['chron1', 'chron2'])

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('chron1 - chron2')
        end

        it 'should create a hypher separated range for start and end chronologies and enumerations' do
            @test_parser.stubs(:_generate_enumeration).once.returns(['enum1', 'enum2'])
            @test_parser.stubs(:_generate_chronology).once.returns(['chron1', 'chron2'])

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('enum1 (chron1) - enum2 (chron2)')
        end

        it 'should create a hypher separated range for a single start chronology and start and end enumerations' do
            @test_parser.stubs(:_generate_enumeration).once.returns(['enum1', 'enum2'])
            @test_parser.stubs(:_generate_chronology).once.returns(['chron1', nil])

            @test_parser.generate_string_representation

            expect(@test_parser.string_rep).to eq('enum1 (chron1) - enum2 (chron1)')
        end
    end

    describe :_generate_enumeration do
        it 'should return comma delimited string of subfields in @@enumeration_codes' do
            test_parser = ParsedField.new(
                { 'a' => '1', 'c' => '3' },
                { 'a' => 'v.', 'b' => 'ser.', 'c' => 'iss.' }
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq('v. 1, iss. 3')
            expect(out_str[1]).to eq(nil)
        end

        it 'should return an empty string if there are no enumeration subfields in the h record' do
            test_parser = ParsedField.new({ 'i' => '1999' }, { 'a' => 'v.' })

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq(nil)
        end

        it 'should return an empty string if there are no subfields in the h record' do
            test_parser = ParsedField.new({}, { 'a' => 'v.' })

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq(nil)
        end

        it 'should remove any subfields if the h record is an empty string' do
            test_parser = ParsedField.new(
                { 'a' => '1', 'b' => '', 'c' => '3' },
                { 'a' => 'v.', 'b' => 'ser.', 'c' => 'i.' }
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq('v. 1, i. 3')
        end

        it 'should combine values with colons if no field names are provided' do
            test_parser = ParsedField.new(
                { 'a' => '1', 'b' => '', 'c' => '3' },
                { 'a' => '', 'b' => '', 'c' => '' }
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq('1:3')
        end

        it 'should combine values with colons and commas if values are mixed' do
            test_parser = ParsedField.new(
                { 'a' => '1', 'b' => '2', 'c' => '3' },
                { 'a' => 'ser.', 'b' => 'vol.', 'c' => '' }
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq('ser. 1, vol. 2:3')
        end

        it 'should set continuing if a hyphen is present in a value' do
            test_parser = ParsedField.new(
                { 'a' => '1-', 'b' => '2', 'c' => '3' },
                { 'a' => 'ser.', 'b' => 'vol.', 'c' => '' }
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq('ser. 1, vol. 2:3')
            expect(out_str[1]).to eq(nil)
            expect(test_parser.instance_variable_get(:@continuing)).to eq(true)
        end

        it 'should create a range of values if for hyphen separated fields' do
            test_parser = ParsedField.new(
                { 'a' => '1-3' }, { 'a' => 'no.' }
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq('no. 1')
            expect(out_str[1]).to eq('no. 3')
        end

        it 'should create a range of combined values for multiple hyphen separeted fields' do
            test_parser = ParsedField.new(
                { 'a' => '1-3', 'b' => '20-40' }, { 'a' => 'vol.', 'b' => '' }
            )

            out_str = test_parser.send(:_generate_enumeration)

            expect(out_str[0]).to eq('vol. 1:20')
            expect(out_str[1]).to eq('vol. 3:40')
        end
    end

    describe :_generate_chronology do
        it 'should pass key/value pairs to DateComponent and get string from created object' do
            test_parser = ParsedField.new(
                { 'i' => '1999', 'j' => 'Mar' },
                { 'i' => 'year', 'j' => '(month)' }
            )

            mock_date_comp = mock
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).once.with('year', '1999')
            mock_date_comp.stubs(:set_field).once.with('month', 'Mar')
            mock_date_comp.stubs(:create_str).once.returns('1999-Mar')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('1999-Mar')
        end

        it 'should pass no fields to DateComponent if no matching subfields exist and return empty string' do
            test_parser = ParsedField.new(
                { 'a' => '1', 'c' => '3' },
                { 'i' => 'year', 'j' => '(month)' }
            )

            mock_date_comp = mock
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).never
            mock_date_comp.stubs(:create_str).once.returns('')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('')
        end

        it 'should omit any fields that are only an empty string' do
            test_parser = ParsedField.new(
                { 'i' => '1999', 'j' => '' },
                { 'i' => 'year', 'j' => 'month' }
            )

            mock_date_comp = mock
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).once.with('year', '1999')
            mock_date_comp.stubs(:create_str).once.returns('1999')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('1999')
        end

        it 'should handle delimiter fields with abreviations' do
            test_parser = ParsedField.new(
                { 'i' => '1999', 'j' => '09', 'k' => '09' },
                { 'i' => '(yr.)', 'j' => 'mo.', 'k' => 'da' }
            )

            mock_date_comp = mock
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).once.with('year', '1999')
            mock_date_comp.stubs(:set_field).once.with('month', '09')
            mock_date_comp.stubs(:set_field).once.with('day', '09')
            mock_date_comp.stubs(:create_str).once.returns('1999-09-09')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('1999-09-09')
        end

        it 'should set continuing to true if a value ends with a hyphen' do
            test_parser = ParsedField.new(
                { 'i' => '1999', 'j' => '23-' },
                { 'i' => 'year', 'j' => '()' }
            )

            mock_date_comp = mock
            ParsedField::DateComponent.stubs(:new).once.returns(mock_date_comp)
            mock_date_comp.stubs(:set_field).once.with('year', '1999')
            mock_date_comp.stubs(:set_field).once.with(nil, '23-')
            mock_date_comp.stubs(:create_str).once.returns('1999-23')

            out_str = test_parser.send(:_generate_chronology)

            expect(out_str).to eq('1999-23')
            expect(test_parser.instance_variable_get(:@continuing)).to eq(true)
        end
    end

    describe :_standardize_date_definition_field do
        it 'should return the full name of a date field for an abbreviation' do
            test_parser = ParsedField.new({}, {})

            out_field = test_parser.send(:_standardize_date_definition_field, '(yr.)')

            expect(out_field).to eq('year')
        end

        it 'should return nil if an empty set of parens is provided' do
            test_parser = ParsedField.new({}, {})

            out_field = test_parser.send(:_standardize_date_definition_field, '()')

            expect(out_field).to eq(nil)
        end

        it 'should raise an error if the date field is not recognized' do
            test_parser = ParsedField.new({}, {})

            expect {
                test_parser.send(:_standardize_date_definition_field, '(smthg.)')
            }.to raise_error(FieldParserError, 'Unable to identify field (smthg.) for chronology')
        end

        it 'should handle cases where fields contain upper case characters' do
            test_parser = ParsedField.new({}, {})

            out_field = test_parser.send(:_standardize_date_definition_field, '(Season)')

            expect(out_field).to eq('season')
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
