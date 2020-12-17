# frozen_string_literal: true

require 'puppet'
require 'puppet/pops'
require 'puppet-strings/yard/parsers/puppet/statement'

# Implements the Puppet language parser.
class PuppetStrings::Yard::Parsers::Puppet::Parser < YARD::Parser::Base
  attr_reader :file, :source, :error

  # Initializes the parser.
  # @param [String] source The source being parsed.
  # @param [String] filename The file name of the file being parsed.
  # @return [void]
  def initialize(source, filename)
    @source = source
    @file = filename
    @visitor = ::Puppet::Pops::Visitor.new(self, 'transform')
  end

  # Parses the source.
  # @return [void]
  def parse
    begin
      Puppet[:tasks] = true if Puppet.settings.include?(:tasks)
      if Puppet::Util::Package.versioncmp(Puppet.version, "5.0.0") < 0 && @file.to_s.match(/^plans\//)
        log.warn "Skipping #{@file}: Puppet Plans require Puppet 5 or greater."
        return
      end
      @statements ||= (@visitor.visit(::Puppet::Pops::Parser::Parser.new.parse_string(source)) || []).compact
      @error = nil
    rescue ::Puppet::ParseError => e
      log.error "Failed to parse #{@file}: #{e.message}"
      @error = e
      @statements = []
    end
    @statements.freeze
    self
  end

  # Gets an enumerator for the statements that were parsed.
  # @return Returns an enumerator for the statements that were parsed.
  def enumerator
    @statements
  end

  private

  def transform_Program(o)
    # Cache the lines of the source text; we'll use this to locate comments
    @lines = o.source_text.lines.to_a
    o.definitions.map { |d| @visitor.visit(d) }
  end

  def transform_Factory(o)
    @visitor.visit(o.current)
  end

  def transform_HostClassDefinition(o)
    statement = PuppetStrings::Yard::Parsers::Puppet::ClassStatement.new(o, @file)
    statement.extract_docstring(@lines)
    statement
  end

  def transform_ResourceTypeDefinition(o)
    statement = PuppetStrings::Yard::Parsers::Puppet::DefinedTypeStatement.new(o, @file)
    statement.extract_docstring(@lines)
    statement
  end

  def transform_FunctionDefinition(o)
    statement = PuppetStrings::Yard::Parsers::Puppet::FunctionStatement.new(o, @file)
    statement.extract_docstring(@lines)
    statement
  end

  def transform_PlanDefinition(o)
    statement = PuppetStrings::Yard::Parsers::Puppet::PlanStatement.new(o, @file)
    statement.extract_docstring(@lines)
    statement
  end

  def transform_TypeAlias(o)
    statement = PuppetStrings::Yard::Parsers::Puppet::DataTypeAliasStatement.new(o, @file)
    statement.extract_docstring(@lines)
    statement
  end

  def transform_Object(o)
    # Ignore anything else (will be compacted out of the resulting array)
  end
end
