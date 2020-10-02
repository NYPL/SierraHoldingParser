require_relative '../lib/record_manager'
require_relative './handler_spec'

describe ParsedField::DateComponent do
    before(:each) {
        @test_comp = ParsedField::DateComponent.new
    }

    describe :initialize do
        it 'should initialize instance variables to nil' do
            expect(@test_comp.instance_variable_get(:@start_year)).to eq(nil)
            expect(@test_comp.instance_variable_get(:@end_day)).to eq(nil)
        end
    end

    describe :set_field do
        it 'should start and end to the value if no dash is present' do
            @test_comp.set_field('year', '1999')

            expect(@test_comp.instance_variable_get(:@start_year)).to eq('1999')
            expect(@test_comp.instance_variable_get(:@end_year)).to eq('1999')
        end

        it 'should start and end to split values if ' do
            @test_comp.set_field('year', '1999-2000')

            expect(@test_comp.instance_variable_get(:@start_year)).to eq('1999')
            expect(@test_comp.instance_variable_get(:@end_year)).to eq('2000')
        end
    end

    describe :create_str do
        it 'should nil values if no date values are provided' do
            expect(@test_comp.create_str).to eq([nil, nil])
        end

        it 'should return a single date string if start and end are identical' do
            @test_comp.instance_variable_set(:@start_year, '1999')
            @test_comp.instance_variable_set(:@end_year, '1999')

            expect(@test_comp.create_str).to eq(['1999', nil])
        end

        it 'should return a single date string with the unknown value at the end if provided' do
            @test_comp.instance_variable_set(:@start_year, '1999')
            @test_comp.instance_variable_set(:@end_year, '1999')
            @test_comp.instance_variable_set(:@start_unknown, '23')
            @test_comp.instance_variable_set(:@end_unknown, '23')

            expect(@test_comp.create_str).to eq(['1999-23', nil])
        end

        it 'should return a date range if start and end are different' do
            @test_comp.instance_variable_set(:@start_year, '1999')
            @test_comp.instance_variable_set(:@end_year, '1999')
            @test_comp.instance_variable_set(:@start_month, '02')
            @test_comp.instance_variable_set(:@end_month, '04')

            expect(@test_comp.create_str).to eq(['1999-02', '1999-04'])
        end
    end
end
