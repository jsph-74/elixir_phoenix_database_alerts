defmodule Alerts.Business.ResultHashTest do
  use Alerts.DataCase, async: true
  
  alias Alerts.Business.AlertResultsHistory

  describe "calculate_result_hash/1" do
    test "generates consistent hash for same CSV data" do
      csv_data = "id,name\n1,John\n2,Jane"
      
      hash1 = AlertResultsHistory.calculate_result_hash(csv_data)
      hash2 = AlertResultsHistory.calculate_result_hash(csv_data)
      
      assert hash1 == hash2
      assert is_binary(hash1)
      assert String.length(hash1) > 10  # Reasonable hash length
    end

    test "generates different hashes for different CSV data" do
      csv1 = "id,name\n1,John"
      csv2 = "id,name\n1,Jane"  # Different data
      
      hash1 = AlertResultsHistory.calculate_result_hash(csv1)
      hash2 = AlertResultsHistory.calculate_result_hash(csv2)
      
      assert hash1 != hash2
    end
  end
end