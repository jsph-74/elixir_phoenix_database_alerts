defmodule Alerts.Business.HelpersTest do
  use Alerts.DataCase
  
  alias Alerts.Business.Helpers

  describe "normalize_value_for_comparison/1" do
    test "normalizes string values by trimming whitespace" do
      assert Helpers.normalize_value_for_comparison("  hello  ") == "hello"
      assert Helpers.normalize_value_for_comparison("test\n\n") == "test"
      assert Helpers.normalize_value_for_comparison("\n  value  \n") == "value"
    end
    
    test "converts numeric strings to integers" do
      assert Helpers.normalize_value_for_comparison("123") == 123
      assert Helpers.normalize_value_for_comparison("  456  ") == 456
      assert Helpers.normalize_value_for_comparison("0") == 0
    end
    
    test "keeps non-numeric strings as strings" do
      assert Helpers.normalize_value_for_comparison("abc123") == "abc123"
      assert Helpers.normalize_value_for_comparison("12.5") == "12.5"
    end
    
    test "handles integers directly" do
      assert Helpers.normalize_value_for_comparison(123) == 123
      assert Helpers.normalize_value_for_comparison(0) == 0
    end
    
    test "converts empty strings to nil" do
      assert Helpers.normalize_value_for_comparison("") == nil
      assert Helpers.normalize_value_for_comparison("  ") == nil
    end
    
    test "handles nil values" do
      assert Helpers.normalize_value_for_comparison(nil) == nil
    end
  end

  describe "get_param_value/2" do
    test "gets value from atom key" do
      params = %{name: "test_value"}
      assert Helpers.get_param_value(params, :name) == "test_value"
    end
    
    test "gets value from string key" do
      params = %{"name" => "test_value"}
      assert Helpers.get_param_value(params, :name) == "test_value"
    end
    
    test "prefers atom key over string key" do
      params = Map.merge(%{"name" => "string_value"}, %{name: "atom_value"})
      assert Helpers.get_param_value(params, :name) == "atom_value"
    end
    
    test "returns nil for missing keys" do
      params = %{other: "value"}
      assert Helpers.get_param_value(params, :name) == nil
    end
  end

  describe "trim_query_params/1" do
    test "trims query field with string key" do
      params = %{"query" => "  SELECT * FROM users  \n\n  "}
      result = Helpers.trim_query_params(params)
      assert result["query"] == "SELECT * FROM users"
    end
    
    test "trims query field with atom key" do
      params = %{query: "\n\n  SELECT 1  "}
      result = Helpers.trim_query_params(params)
      assert result[:query] == "SELECT 1"
    end
    
    test "handles string keys" do
      params = %{"query" => "  SELECT 2  "}
      result = Helpers.trim_query_params(params)
      assert result["query"] == "SELECT 2"
    end
    
    test "handles atom keys" do
      params = %{query: "\n  SELECT 3  \n"}
      result = Helpers.trim_query_params(params)
      assert result[:query] == "SELECT 3"
    end
    
    test "leaves nil query unchanged" do
      params = %{"query" => nil}
      result = Helpers.trim_query_params(params)
      assert result["query"] == nil
      
      params_atom = %{query: nil}
      result_atom = Helpers.trim_query_params(params_atom)
      assert result_atom[:query] == nil
    end
    
    test "leaves non-string values unchanged" do
      params = %{"query" => 123}
      result = Helpers.trim_query_params(params)
      assert result["query"] == 123
    end
  end

  describe "trim_query/1" do
    test "trims whitespace and newlines" do
      assert Helpers.trim_query("  SELECT 1  ") == "SELECT 1"
      assert Helpers.trim_query("\n\nSELECT 2\n\n") == "SELECT 2"
      assert Helpers.trim_query("  \n  SELECT 3  \n  ") == "SELECT 3"
    end
    
    test "handles nil" do
      assert Helpers.trim_query(nil) == nil
    end
    
    test "handles non-string values" do
      assert Helpers.trim_query(123) == 123
      assert Helpers.trim_query(%{query: "test"}) == %{query: "test"}
    end
  end

  describe "has_meaningful_changes?/3" do
    test "detects changes in meaningful fields" do
      struct = %{name: "Original", description: "Original desc", query: "SELECT 1"}
      params = %{"name" => "Updated", "description" => "Original desc"}
      fields = [:name, :description, :query]
      
      assert Helpers.has_meaningful_changes?(struct, params, fields) == true
    end
    
    test "ignores non-meaningful fields" do
      struct = %{name: "Original", other_field: "Original"}
      params = %{"name" => "Original", "other_field" => "Updated"}
      fields = [:name]  # other_field not in meaningful fields
      
      assert Helpers.has_meaningful_changes?(struct, params, fields) == false
    end
    
    test "normalizes values for comparison" do
      struct = %{query: "SELECT 1"}
      params = %{"query" => "  SELECT 1  \n\n"}  # Same after trimming
      fields = [:query]
      
      assert Helpers.has_meaningful_changes?(struct, params, fields) == false
    end
    
    test "detects numeric changes" do
      struct = %{threshold: 10}
      params = %{"threshold" => "20"}  # String that becomes 20
      fields = [:threshold]
      
      assert Helpers.has_meaningful_changes?(struct, params, fields) == true
    end
    
    test "handles atom and string keys in params" do
      struct = %{name: "Original"}
      
      # String key
      params_string = %{"name" => "Updated"}
      fields = [:name]
      assert Helpers.has_meaningful_changes?(struct, params_string, fields) == true
      
      # Atom key
      params_atom = %{name: "Updated"}
      assert Helpers.has_meaningful_changes?(struct, params_atom, fields) == true
    end
  end
end