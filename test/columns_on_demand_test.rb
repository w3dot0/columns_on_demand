require 'test_helper'
require 'schema'

class Explicit < ActiveRecord::Base
  columns_on_demand :file_data, :processing_log, :original_filename
end

class Implicit < ActiveRecord::Base
  columns_on_demand
end

class Parent < ActiveRecord::Base
  columns_on_demand
  
  has_many :children
end

class Child < ActiveRecord::Base
  columns_on_demand
  
  belongs_to :parent
end

class ColumnsOnDemandTest < ActiveSupport::TestCase
  def assert_not_loaded(record, attr_name)
    assert_equal nil, record.instance_variable_get("@attributes")[attr_name.to_s]
  end
  
  fixtures :all
  self.use_transactional_fixtures = true
  
  test "it lists explicitly given columns for loading on demand" do
    assert_equal ["file_data", "processing_log", "original_filename"], Explicit.columns_to_load_on_demand
  end

  test "it lists all :binary and :text columns for loading on demand if none are explicitly given" do
    assert_equal ["file_data", "processing_log", "results"], Implicit.columns_to_load_on_demand
  end
  
  test "it selects all the other columns for loading eagerly" do
    assert_match /\W*id\W*, \W*results\W*, \W*processed_at\W*/, Explicit.default_select(false)
    assert_match /\W*explicits\W*.results/, Explicit.default_select(true)
    
    assert_match /\W*id\W*, \W*original_filename\W*, \W*processed_at\W*/, Implicit.default_select(false)
    assert_match /\W*implicits\W*.original_filename/, Implicit.default_select(true)
  end
  
  test "it doesn't load the columns_to_load_on_demand straight away when finding the records" do
    record = Implicit.find(:first)
    assert_not_equal nil, record
    assert_not_loaded record, "file_data"
    assert_not_loaded record, "processing_log"

    record = Implicit.find(:all).first
    assert_not_equal nil, record
    assert_not_loaded record, "file_data"
    assert_not_loaded record, "processing_log"
  end
  
  test "it loads the columns when accessed as an attribute" do
    record = Implicit.find(:first)
    assert_equal "This is the file data!", record.file_data
    assert_equal "Processed 0 entries OK", record.results
    assert_equal record.results.object_id, record.results.object_id # should not have to re-find

    record = Implicit.find(:all).first
    assert_not_equal nil, record.file_data
  end
  
  test "it loads the column when accessed using read_attribute" do
    record = Implicit.find(:first)
    assert_equal "This is the file data!", record.read_attribute(:file_data)
    assert_equal "This is the file data!", record.read_attribute("file_data")
    assert_equal "Processed 0 entries OK", record.read_attribute("results")
    assert_equal record.read_attribute(:results).object_id, record.read_attribute("results").object_id # should not have to re-find
  end
  
  test "it loads the column when generating #attributes" do
    attributes = Implicit.find(:first).attributes
    assert_equal "This is the file data!", attributes["file_data"]
  end
  
  test "it loads the column when generating #to_json" do
    json = Implicit.find(:first)
    assert_equal "This is the file data!", ActiveSupport::JSON.decode(json["file_data"])
  end
  
  test "it clears the column on reload, and can load it again" do
    record = Implicit.find(:first)
    old_object_id = record.file_data.object_id
    Implicit.update_all(:file_data => "New file data")

    record.reload

    assert_not_loaded record, "file_data"
    assert_equal "New file data", record.file_data
  end
  
  test "it doesn't override custom :select finds" do
    record = Implicit.find(:first, :select => "id, file_data")
    klass = ActiveModel.const_defined?(:MissingAttributeError) ? ActiveModel::MissingAttributeError : ActiveRecord::MissingAttributeError
    assert_raise klass do
      record.processed_at # explicitly not loaded, overriding default
    end
    assert_equal "This is the file data!", record.instance_variable_get("@attributes")["file_data"] # already loaded, overriding default
  end
  
  test "it raises normal ActiveRecord::RecordNotFound if the record is deleted before the column load" do
    record = Implicit.find(:first)
    Implicit.delete_all
    
    assert_raise ActiveRecord::RecordNotFound do
      record.file_data
    end
  end
  
  test "it doesn't raise on column access if the record is deleted after the column load" do
    record = Implicit.find(:first)
    record.file_data
    Implicit.delete_all
    
    assert_equal "This is the file data!", record.file_data # check it doesn't raise
  end
  
  test "it updates the select strings when columns are changed and the column information is reset" do
    ActiveRecord::Schema.define(:version => 1) do
      create_table :dummies, :force => true do |t|
        t.string   :some_field
        t.binary   :big_field
      end
    end

    class Dummy < ActiveRecord::Base
      columns_on_demand
    end

    assert_match /\W*id\W*, \W*some_field\W*/, Dummy.default_select(false)

    ActiveRecord::Schema.define(:version => 2) do
      create_table :dummies, :force => true do |t|
        t.string   :some_field
        t.binary   :big_field
        t.string   :another_field
      end
    end

    assert_match /\W*id\W*, \W*some_field\W*/, Dummy.default_select(false)
    Dummy.reset_column_information
    assert_match /\W*id\W*, \W*some_field\W*, \W*another_field\W*/, Dummy.default_select(false)
  end
  
  test "it handles STI models" do
    ActiveRecord::Schema.define(:version => 1) do
      create_table :stis, :force => true do |t|
        t.string   :type
        t.string   :some_field
        t.binary   :big_field
      end
    end

    class Sti < ActiveRecord::Base
      columns_on_demand
    end
    
    class StiChild < Sti
      columns_on_demand :some_field
    end

    assert_match /\W*id\W*, \W*type\W*, \W*some_field\W*/, Sti.default_select(false)
    assert_match /\W*id\W*, \W*type\W*, \W*big_field\W*/,  StiChild.default_select(false)
  end
  
  test "it works on child records loaded from associations" do
    parent = parents(:some_parent)
    child = parent.children.find(:first)
    assert_not_loaded child, "test_data"
    assert_equal "Some test data", child.test_data
  end
  
  test "it works on parent records loaded from associations" do
    child = children(:a_child_of_some_parent)
    parent = child.parent
    assert_not_loaded parent, "info"
    assert_equal "Here's some info.", parent.info
  end
  
  test "it doesn't break validates_presence_of" do
    class ValidatedImplicit < ActiveRecord::Base
      set_table_name "implicits"
      columns_on_demand
      validates_presence_of :original_filename, :file_data, :results
    end
    
    assert !ValidatedImplicit.new(:original_filename => "test.txt").valid?
    instance = ValidatedImplicit.create!(:original_filename => "test.txt", :file_data => "test file data", :results => "test results")
    instance.update_attributes!({}) # file_data and results are already loaded
    new_instance = ValidatedImplicit.find(instance.id)
    new_instance.update_attributes!({}) # file_data and results aren't loaded yet, but will be loaded to validate
  end
  
  test "it works with serialized columns" do
    class Serializing < ActiveRecord::Base
      columns_on_demand
      serialize :data
    end
    
    data = {:foo => '1', :bar => '2', :baz => '3'}
    original_record = Serializing.create!(:data => data)
    assert_equal data, original_record.data
    
    record = Serializing.find(:first)
    assert_not_loaded record, "data"
    assert_equal data, record.data
    assert_equal false, record.data_changed?
    assert_equal false, record.changed?
    assert_equal data, record.data
    
    record.data = "replacement"
    assert_equal true, record.data_changed?
    assert_equal true, record.changed?
    record.save!
    
    record = Serializing.find(:first)
    assert_not_loaded record, "data"
    assert_equal "replacement", record.data
  end
end
