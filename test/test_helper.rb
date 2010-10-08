# encoding: UTF-8
require 'test/unit'
require 'rubygems'
require 'bundler'
Bundler.setup
require 'shoulda'
require 'mocha'
require 'tiny_tds'

TINYTDS_SCHEMAS = ['sqlserver_2000', 'sqlserver_2005', 'sqlserver_2008'].freeze

module TinyTds
  class TestCase < Test::Unit::TestCase
    
    class << self
      
      def current_schema
        ENV['TINYTDS_SCHEMA'] || 'sqlserver_2008'
      end
      
      TINYTDS_SCHEMAS.each do |schema|
        define_method "#{schema}?" do
          schema == self.current_schema
        end
      end
      
    end
    
    def test_base_tiny_tds_case ; assert(true) ; end
    
    
    protected
    
    TINYTDS_SCHEMAS.each do |schema|
      define_method "#{schema}?" do
        schema == self.class.current_schema
      end
    end
    
    def current_schema
      self.class.current_schema
    end
    
    def connection_options(options={})
      { :host          => ENV['TINYTDS_UNIT_HOST'] || 'localhost',
        :username      => 'tinytds',
        :password      => '',
        :database      => 'tinytds_test',
        :appname       => 'TinyTds Dev',
        :login_timeout => 5,
        :timeout       => 5
      }.merge(options)
    end
    
    def assert_raise_tinytds_error(action)
      error_raised = false
      begin
        action.call
      rescue TinyTds::Error => e
        error_raised = true
      end
      assert error_raised, 'expected a TinyTds::Error but none happened'
      yield e
    end
    
    def inspect_tinytds_exception
      begin
        yield
      rescue TinyTds::Error => e
        props = { :source => e.source, :message => e.message, :severity => e.severity, 
                  :db_error_number => e.db_error_number, :os_error_number => e.os_error_number }
        raise "TinyTds::Error - #{props.inspect}"
      end
    end
    
    def assert_binary_encoding(value)
      assert_equal Encoding.find('BINARY'), value.encoding if ruby19?
    end
    
    def assert_utf8_encoding(value)
      assert_equal Encoding.find('UTF-8'), value.encoding if ruby19?
    end
    
    def ruby18?
      RUBY_VERSION < '1.9'
    end
    
    def ruby19?
      RUBY_VERSION >= '1.9'
    end
    
    def load_current_schema
      @@current_schema_loaded ||= begin
        loader = TinyTds::Client.new(connection_options)
        schema_file = File.expand_path File.join(File.dirname(__FILE__), 'schema', "#{current_schema}.sql")
        schema_sql = File.read(schema_file)
        loader.execute(drop_sql).each
        loader.execute(schema_sql).cancel
        loader.close
        true
      end
    end

    def drop_sql
      %|IF  EXISTS (
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_CATALOG = 'tinytds_test' 
        AND TABLE_TYPE = 'BASE TABLE' 
        AND TABLE_NAME = 'datatypes'
      ) 
      DROP TABLE [datatypes]|
    end

    def find_value(id, column)
      sql = "SELECT [#{column}] FROM [datatypes] WHERE [id] = #{id}"
      @client.execute(sql).each.first[column.to_s]
    end
    
    
  end
end

