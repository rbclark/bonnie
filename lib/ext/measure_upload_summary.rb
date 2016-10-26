module UploadSummary
  
  SLICER = HQMF::PopulationCriteria::ALL_POPULATION_CODES + ['rationale', 'finalSpecifics']
  
  class MeasureSummary

    include Mongoid::Document
    include Mongoid::Timestamps
    
    store_in collection: 'upload_summaries'

    field :hqmf_id, type: String
    field :hqmf_set_id, type: String
    field :upload_dtm, type: Time, default: -> { Time.current }
    field :measure_db_id_before, type: BSON::ObjectId # The mongoid id of the measure before it is archived
    field :measure_db_id_after, type: BSON::ObjectId # The mongoid id of the measure post_upload_results it is has been updated
    field :measure_cms_id_before, type: String
    field :measure_cms_id_after, type: String
    field :measure_hqmf_version_number_before, type: String
    field :measure_hqmf_version_number_after, type: String
    belongs_to :user
    embeds_many :population_summaries, cascade_callbacks: true
    accepts_nested_attributes_for :population_summaries
    
    index "user_id" => 1
    scope :by_user, ->(user) { where({'user_id'=>user.id}) }
    scope :by_user_and_hqmf_set_id, ->(user, hqmf_set_id) { where({'user_id'=>user.id, 'hqmf_set_id'=>hqmf_set_id}) }
  end
  
  class PopulationSummary
    include Mongoid::Document
    include Mongoid::Timestamps
    field :patients, type: Hash, default: {}
    field :summary, type: Hash, default: { pass_before: 0, pass_after: 0, fail_before: 0, fail_after: 0 }
    embedded_in :measure_summaries

    def before_measure_load_compare(patient, pop_idx, m_id)
      # Handle when measure has more populations 
      pat_pop_idx = []
      patient.expected_values.each { |e| pat_pop_idx << e[:population_index] if e[:measure_id] == m_id }
      return if pop_idx > pat_pop_idx.max

      trim_before = (patient.calc_results.find {|p| p[:measure_id] == m_id && p[:population_index] == pop_idx }).slice(*SLICER) unless patient.results_exceed_storage
      trim_expected = (patient.expected_values.find {|p| p[:measure_id] == m_id && p[:population_index] == pop_idx }).slice(*SLICER)

      # TODO: Make sure this can handle continuous value measures.
      if !patient.results_exceed_storage
        if (patient.calc_results.find{ |p| p[:measure_id] == m_id && p[:population_index] == pop_idx })['status'] == 'pass'
          status = 'pass'
          self.summary[:pass_before] += 1
        else
          status = 'fail'
          self.summary[:fail_before] += 1
        end
      else
        if (patient.condensed_bc_of_size_results.find{ |p| p[:measure_id] == m_id && p[:population_index] == pop_idx })['status'] == 'pass'
          status = 'pass'
          self.summary[:pass_before] += 1
        else
          status = 'fail'
          self.summary[:fail_before] += 1
        end
      end
      self[:patients][patient.id.to_s] = {
        expected: trim_expected,
        pre_upload_results: trim_before,
        pre_upload_status: status,
        results_exceeds_storage_pre_upload: patient.results_exceed_storage }
      self[:patients][patient.id.to_s].merge!(patient_version_at_upload: patient.version) unless !patient.version
    end
  end

  def self.collect_before_upload_state(measure, arch_measure)
    patients = Record.where(user_id: measure.user_id, measure_ids: measure.hqmf_set_id)

    mups = MeasureSummary.new
    measure.populations.each_with_index do |m, index|
      moo = PopulationSummary.new
      patients.each do |patient|
        moo.before_measure_load_compare(patient, index, measure.hqmf_set_id)
      end
      mups.population_summaries << moo
    end
    mups.hqmf_id = measure.hqmf_id
    mups.hqmf_set_id = measure.hqmf_set_id
    mups.user_id = measure.user_id
    if arch_measure
      mups.measure_db_id_before = arch_measure.measure_db_id
      mups.measure_cms_id_before = arch_measure.measure_hash['cms_id']
      mups.measure_hqmf_version_number_before = arch_measure.measure_hash['hqmf_version_number']
    end
    mups.measure_db_id_after = measure.id
    mups.measure_cms_id_after = measure.cms_id
    mups.measure_hqmf_version_number_after = measure.hqmf_version_number
    mups.save!
    mups.id
  end

  def self.collect_after_upload_state(measure, upload_summary_id)
    the_befores = MeasureSummary.where(id: upload_summary_id).first
    the_befores.population_summaries.each_index do |pop_idx|
      b_mups = the_befores.population_summaries[pop_idx]
      b_mups[:patients].keys.each do |patient|
        ptt = Record.where(id: patient).first
        trim_after = (ptt.calc_results.find { |p| p[:measure_id] == measure.hqmf_set_id && p[:population_index] == pop_idx }).slice(*SLICER) unless ptt.results_exceed_storage
        if !ptt.results_exceed_storage
          if (ptt.calc_results.find{ |p| p[:measure_id] == measure.hqmf_set_id && p[:population_index] == pop_idx })['status'] == 'pass'
            status = 'pass'
            b_mups.summary[:pass_after] += 1
          else
            status = 'fail'
            b_mups.summary[:fail_after] += 1
          end
        else
          if (ptt.condensed_bc_of_size_results.find{ |p| p[:measure_id] == measure.hqmf_set_id && p[:population_index] == pop_idx })['status'] == 'pass'
            status = 'pass'
            b_mups.summary[:pass_after] += 1
          else
            status = 'fail'
            b_mups.summary[:fail_after] += 1
          end
        end 
        b_mups.patients[patient].merge!(post_upload_results: trim_after, post_upload_status: status, results_exceeds_storage_post_upload: ptt.results_exceed_storage, patient_version_after_upload: ptt.version)
      end
      b_mups.save!
    end
  end

  def self.calculate_updated_actuals(measure)
    calculator = BonnieBackendCalculator.new
    measure.populations.each_with_index do |population, population_index|
      # Set up calculator for this measure and population, making sure we regenerate the javascript
      begin
        calculator.set_measure_and_population(measure, population_index, clear_db_cache: true, rationale: true)
      rescue => e
        setup_exception = "Measure setup exception: #{e.message}"
      end
      patients = Record.where(user_id: measure.user_id, measure_ids: measure.hqmf_set_id)
      patients.each do |patient|
        unless setup_exception
          begin
            result = calculator.calculate(patient).slice(*SLICER)
          rescue => e
            calculation_exception = "Measure calculation exception: #{e.message}"
          end
        end
        result[:measure_id] = measure.hqmf_set_id
        result[:population_index] = population_index
        if !patient.calc_results.nil?
          calc_results = patient.calc_results.dup
          # Clear any prior results for this measure to ensure a clean update, i.e. a change in the number of populations.
          calc_results.reject! { |av| av['measure_id'] == measure.hqmf_set_id && (av['population_index'] == population_index || av['population_index'] >= measure.populations.count) }
          calc_results << result
          patient.calc_results = calc_results
        else
          patient.calc_results = [result]
        end

        patient.has_measure_history = true
        patient.save!
      end
    end
  end

end