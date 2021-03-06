require 'test_helper'

class RecordTest < ActiveSupport::TestCase
  setup do
    dump_database
    measures_set = File.join("cql_measures", "CMS72v5")
    records_set = File.join("records", "expected_values_set")
    collection_fixtures(measures_set, records_set)
    @measure_set_id = '93F3479F-75D8-4731-9A3F-B7749D8BCD37'
    @measure = CqlMeasure.where(hqmf_set_id: @measure_set_id).first
  end

  # Runs the update_expected_value_structure! method on the patient and collects the changes it yields.
  def collect_expected_changes(patient, measure)
    changes = []
    patient.update_expected_value_structure!(measure) do |change_type, change_reason, expected_value_set|
      changes << {
        change_type: change_type,
        change_reason: change_reason,
        expected_value_set: expected_value_set
      }
    end
    changes
  end

  test "Good Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Good').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 0, changes.count
    assert_equal 1, patient.expected_values.count
  end

  test "Duplicate Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Duplicate').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 1, changes.count

    # check duplicate population set removal
    assert_equal :population_set_removal, changes[0][:change_type]
    assert_equal :dup_population, changes[0][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 0}
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 0}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end

  test "Extra Population Set Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Extra Population Set').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 1, changes.count

    # check extra population set removal
    assert_equal :population_set_removal, changes[0][:change_type]
    assert_equal :extra_population, changes[0][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 1,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 1}
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 1}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end

  test "Extra Population Set Multiple Measure Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Extra Population Set Multiple Measure').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 1, changes.count

    # check extra population set removal
    assert_equal :population_set_removal, changes[0][:change_type]
    assert_equal :extra_population, changes[0][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 1,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 0}
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 0},
      { "measure_id" => "4DF3479F-82F4-183B-9254-F2492BA43523", "population_index" => 0,
        "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 0}]
    assert_equal 2, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end

  test "Garbage and Duplicate Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Garbage and Duplicate').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 2, changes.count

    # check garbage data removal
    assert_equal :population_set_removal, changes[0][:change_type]
    assert_equal :garbage_data, changes[0][:change_reason]
    expected_value_set = { "measure_id" => '93F3479F-75D8-4731-9A3F-B7749D8BCD37' }
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check duplicate population set removal
    assert_equal :population_set_removal, changes[1][:change_type]
    assert_equal :dup_population, changes[1][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 0}
    assert_equal expected_value_set, changes[1][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 0}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end

  test "Garbage Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Garbage').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 1, changes.count

    # check garbage data removal
    assert_equal :population_set_removal, changes[0][:change_type]
    assert_equal :garbage_data, changes[0][:change_reason]
    expected_value_set = { "measure_id" => '93F3479F-75D8-4731-9A3F-B7749D8BCD37' }
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 0, "NUMER" => 1, "DENEXCEP" => 0}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end

  test "Garbage Empty Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Garbage Empty').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 1, changes.count

    # check garbage data removal of a blank set
    assert_equal :population_set_removal, changes[0][:change_type]
    assert_equal :garbage_data, changes[0][:change_reason]
    expected_value_set = { }
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 0, "NUMER" => 1, "DENEXCEP" => 0}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end

  test "Missing Population Set Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Missing Population Set').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 2, changes.count

    # check missing population set addition
    assert_equal :population_set_addition, changes[0][:change_type]
    assert_equal :missing_population, changes[0][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 0 }
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check missing populations additions
    assert_equal :population_addition, changes[1][:change_type]
    assert_equal :missing_population, changes[1][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 0, "DENOM" => 0, "DENEX" => 0, "NUMER" => 0, "DENEXCEP" => 0}
    assert_equal expected_value_set, changes[1][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 0, "DENOM" => 0, "DENEX" => 0, "NUMER" => 0, "DENEXCEP" => 0}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end

  test "Missing Population Set With Garbage Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Missing Population Set With Garbage').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 3, changes.count

    # check garbage data removal
    assert_equal :population_set_removal, changes[0][:change_type]
    assert_equal :garbage_data, changes[0][:change_reason]
    expected_value_set = { "measure_id" => '93F3479F-75D8-4731-9A3F-B7749D8BCD37' }
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check missing population set addition
    assert_equal :population_set_addition, changes[1][:change_type]
    assert_equal :missing_population, changes[1][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 0 }
    assert_equal expected_value_set, changes[1][:expected_value_set]

    # check missing populations additions
    assert_equal :population_addition, changes[2][:change_type]
    assert_equal :missing_population, changes[2][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 0, "DENOM" => 0, "DENEX" => 0, "NUMER" => 0, "DENEXCEP" => 0}
    assert_equal expected_value_set, changes[2][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 0, "DENOM" => 0, "DENEX" => 0, "NUMER" => 0, "DENEXCEP" => 0}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end

  test "Missing Population Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Missing Population').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 1, changes.count

    # check missing population addition
    assert_equal :population_addition, changes[0][:change_type]
    assert_equal :missing_population, changes[0][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 0,
      "DENEXCEP" => 0}
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 1, "DENOM" => 1, "DENEX" => 1, "NUMER" => 0, "DENEXCEP" => 0}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end
  
  test "Extra Population Expecteds" do
    patient = Record.where(last: 'Expecteds', first: 'Extra Population').first
    changes = collect_expected_changes(patient, @measure)
    assert_equal 1, changes.count
    
    # check missing population set addition
    assert_equal :population_removal, changes[0][:change_type]
    assert_equal :extra_population, changes[0][:change_reason]
    expected_value_set = { "measure_id" => @measure_set_id, "population_index" => 0,
      "NUMEX" => 0 }
    assert_equal expected_value_set, changes[0][:expected_value_set]

    # check final expecteds structure
    expected_value_sets = [{ "measure_id" => @measure_set_id, "population_index" => 0,
      "IPP" => 0, "DENOM" => 0, "DENEX" => 0, "NUMER" => 0, "DENEXCEP" => 0}]
    assert_equal 1, patient.expected_values.count
    assert_equal expected_value_sets, patient.expected_values
  end
end
