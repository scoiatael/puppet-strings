# frozen_string_literal: true

require 'spec_helper'
require 'puppet-strings/markdown'
require 'puppet-strings/markdown/table_of_contents'
require 'tempfile'

describe PuppetStrings::Markdown do
  let(:fixture_path) do
    File.expand_path("../../fixtures", __dir__)
  end

  def fixture_content(fixture)
    @fixtures ||= {}
    @fixtures[fixture] ||= File.read(File.join(fixture_path, fixture))
  end

  def assert_parses(parser)
    expect(parser.error).to be_nil
  end

  def parse_shared_content
    # Populate the YARD registry with both Puppet and Ruby source
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("puppet/class.pp"), :puppet)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("puppet/function.pp"), :puppet)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("ruby/func4x.rb"), :ruby)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("ruby/func4x_1.rb"), :ruby)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("ruby/func3x.rb"), :ruby)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("ruby/func3x.rb"), :ruby)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("ruby/provider.rb"), :ruby)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("ruby/resource_type.rb"), :ruby)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("ruby/resource_api.rb"), :ruby)

    # task metadata derives the task name from the filename, so we have to parse
    # directly from the filesystem to correctly pick up the name
    assert_parses YARD::Parser::SourceParser.parse(File.join(fixture_path, "json/backup.json"))
  end

  def parse_plan_content
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("puppet/plan.pp"), :puppet)
  end

  def parse_data_type_content
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("ruby/data_type.rb"), :ruby)
    assert_parses YARD::Parser::SourceParser.parse_string(fixture_content("puppet/type_alias.pp"), :puppet)
  end

  let(:output) { PuppetStrings::Markdown.generate }

  RSpec.shared_examples 'markdown lint checker' do |parameter|
    it 'should not generate markdown lint errors from the rendered markdown', if: mdl_available do
      expect(output).to have_no_markdown_lint_errors
    end
  end

  describe 'markdown rendering' do
    before(:each) do
      parse_shared_content
    end

    include_examples 'markdown lint checker'

    describe 'table of contents' do
      it 'includes links to public classes' do
        expect(output).to match(/\[`klass`\]\(#.*\).*simple class/i)
      end

      it 'includes links to private classes' do
        expect(output).to match(/`noparams`.*overview.*noparams/i)
      end

      it 'includes links to defined types' do
        expect(output).to match(/\[`klass::dt`\]\(#.*\).*simple defined type/i)
      end

      it 'includes links to resource types' do
        expect(output).to match(/\[`apt_key`\]\(#.*\).*resource type.*new api/i)
        expect(output).to match(/\[`database`\]\(#.*\).*example database.*type/i)
      end

      it 'includes links to functions' do
        expect(output).to match(/\[`func`\]\(#.*\).*simple puppet function/i)
        expect(output).to match(/\[`func3x`\]\(#.*\).*example 3\.x function/i)
        expect(output).to match(/\[`func4x`\]\(#.*\).*example 4\.x function/i)
        expect(output).to match(/\[`func4x_1`\]\(#.*\).*example 4\.x function.*one signature/i)
      end

      it 'includes links to tasks' do
        expect(output).to match(/\[`backup`\]\(#.*\).*backup your database/i)
      end
    end

    describe 'resource types' do
      it 'includes checks in parameter list for the database type' do
        expect(output).to match(/check to see if the database already exists/i)
      end
    end

    describe 'with Puppet Plans', :if => TEST_PUPPET_PLANS do
      before(:each) do
        parse_plan_content
      end

      include_examples 'markdown lint checker'

      describe "table of contents" do
        it 'includes links to plans' do
          expect(output).to match(/\[`plann`\]\(#.*\).*simple plan/i)
        end
      end
    end

    describe 'with Puppet Data Types', :if => TEST_PUPPET_DATATYPES do
      before(:each) do
        parse_data_type_content
      end

      include_examples 'markdown lint checker'

      describe 'table of contents' do
        it 'includes links to data types' do
          expect(output).to match(/\[`Amodule::ComplexAlias`\]\(#.*\).*Amodule::ComplexAlias/i)
          expect(output).to match(/\[`Amodule::SimpleAlias`\]\(#.*\).*Amodule::SimpleAlias/i)
          expect(output).to match(/\[`UnitDataType`\]\(#.*\).*data type in ruby/i)
        end
      end

      describe 'parameter docs' do
        it 'includes param name' do
          expect(output).to match(/#+ `param1`/)
        end

        it 'includes param type' do
          expect(output).to match(/Data type: `Variant\[Numeric, String\[1,2\]\]`/)
        end

        it 'includes param description' do
          expect(output).to match(/a variant parameter/i)
        end

        it 'includes param default' do
          expect(output).to match(/default value: `param2`/i)
        end
      end

      describe 'function docs' do
        it 'includes signature' do
          expect(output).to match(/UnitDataType\.func1\(param1, param2\)/)
        end

        it 'includes summary' do
          expect(output).to match(/func1 documentation/i)
        end

        it 'includes parameter docs' do
          expect(output).to match(/param1 documentation/i)
        end

        it 'includes return value' do
          expect(output).to match(/returns: `optional\[string\]`/i)
        end
      end
    end
  end
end
