class Thorax.Models.Result extends Thorax.Model
  initialize: (attrs, options) ->
    @population = options.population
    @measure = @population.collection.parent
    @patient = options.patient

    # Provide a deferred that allows usage of a result to be deferred until it's populated
    @calculation = $.Deferred()
    if @isPopulated() then @calculation.resolve() else @once 'change:rationale', -> @calculation.resolve()

    # When a patient changes, is materialized, or is destroyed, we need to respond appropriately
    @listenTo @patient, 'change materialize destroy', =>
      bonnie.calculator.clearResult(@population, @patient) # Remove the result from the cache
      @destroy() # Destroy the result to remove it from any collections

  isPopulated: -> @has('rationale')

  differenceFromExpected: ->
    expected = @patient.getExpectedValue @population
    new Thorax.Models.Differnece({}, result: this, expected: expected)

  specificsRationale: ->
    updatedRationale = {}
    rationale = @get('rationale')
    orCounts = @calculateOrCounts(rationale)
    for code in Thorax.Models.Measure.allPopulationCodes
      if specifics = @get('finalSpecifics')?[code]
        updatedRationale[code] ||= {} # FIXME why '||=' instead of '=' ?
        # get the referenced occurrences in the logic tree
        occurrences = @population.getDataCriteriaKeys(@measure.get('population_criteria')[code])
        # get the good and bad specifics
        occurrenceResults = @checkSpecificsForRationale(specifics, occurrences, @measure.get('data_criteria'))
        parentMap = @buildParentMap(@measure.get('population_criteria')[code])

        # check each bad occurrence and remove highlights marking true
        for badOccurrence in occurrenceResults.bad
          if (rationale[badOccurrence])
            updatedRationale[code][badOccurrence] = false
            # move up the logic tree to set AND/ORs to false based on the removal of the bad specific's true eval
            @updateLogicTree(updatedRationale, rationale, code, badOccurrence, orCounts, parentMap)
        # check the good specifics with a negated parent.  If there are multiple candidate specifics
        # and one is good while the other is bad, the child of the negation will evaluate to true, we want it to
        # evaluate to false since if there's a good negation then there's an occurrence for which it evaluated to false
        for goodOccurrence in occurrenceResults.good
          @updatedNegatedGood(updatedRationale[code], rationale, goodOccurrence, parentMap)
    return updatedRationale

  updatedRationale: ->
    updatedRationale = @specificsRationale()
    currentRationale = @get 'rationale'
    cleanup = []
    for code in @population.populationCriteria() when currentRationale[code]?
      for key, value of currentRationale
        if _(updatedRationale).has(code) and updatedRationale[code][key] is false then cleanup.push(key)
    _(currentRationale).omit(cleanup)

  updatedNegatedGood: (updatedRationale, rationale, goodOccurrence, parentMap) ->
    parent = parentMap[goodOccurrence]
    while parent
      if (parent.negation && rationale[goodOccurrence])
        updatedRationale[goodOccurrence] = false
        return
      parent = parentMap["precondition_#{parent.id}"]

  # get good and bad specific occurrences referenced in this part of the measure
  checkSpecificsForRationale: (finalSpecifics, occurrences, dataCriteriaMap) ->
    results = {bad: occurrences, good: []}
    # if we dont't have any specifics rows then they are all bad
    return results if finalSpecifics.length == 0
    results.bad = []
    # check for good and bad specifics.  Bad will be used to clear out logical true values that are false
    # when specifics are applied.  Good will be used to fix negations of specific occurrences
    for occurrence in occurrences
      index = hqmf.SpecificsManager.indexLookup[dataCriteriaMap[occurrence].source_data_criteria]
      good = false
      # we're good if the occurrence is referenced by ID, Any indicates that we did not use it in the true path, thus it's bad
      for row in finalSpecifics
        good = true if row[index] != hqmf.SpecificsManager.any
      if good then results.good.push(occurrence) else results.bad.push(occurrence)
    results

  # from each leaf walk up the tree updating the logical statements appropriately to false
  updateLogicTree: (updatedRationale, rationale, code, badOccurrence, orCounts, parentMap) ->
    parents = parentMap[badOccurrence]
    @updateLogicTreeChildren(updatedRationale, rationale, code, parents, orCounts, parentMap)

  updateLogicTreeChildren: (updatedRationale, rationale, code, parents, orCounts, parentMap) ->
    return unless parents
    for parent in parents
      parentKey = if parent.id? then "precondition_#{parent.id}" else parent.key || parent.type

      negated = parent.negation
      if updatedRationale[code][parentKey] != false && !negated
        # if this is an OR then remove a true increment since it's a bad true
        orCounts[parentKey]-- if orCounts[parentKey]?
        # if we're either an AND or we're an OR and the count is zero then switch to false and move up the tree
        if ((!orCounts[parentKey]? || orCounts[parentKey] == 0) && (!!rationale[parentKey] == true || rationale[parentKey] == undefined))
          updatedRationale[code][parentKey] = false if rationale[parentKey]?
          @updateLogicTreeChildren(updatedRationale, rationale, code, parentMap[parentKey], orCounts, parentMap)

  buildParentMap: (root) ->
    dataCriteriaMap = @measure.get('data_criteria')
    parentMap = {}
    return parentMap unless root
    if root.preconditions?.length > 0
      for precondition in root.preconditions
        parentMap["precondition_#{precondition.id}"] = (parentMap["precondition_#{precondition.id}"] || []).concat root
        @mergeParentMaps(parentMap, @buildParentMap(precondition))
    else if root.reference?
      parentMap[root.reference] = (parentMap[root.reference] || []).concat root
      @mergeParentMaps(parentMap, @buildParentMap(dataCriteriaMap[root.reference]))
    else
      if root.temporal_references?
        for temporal_reference in root.temporal_references
          if temporal_reference.reference != 'MeasurePeriod'
            parentMap[temporal_reference.reference] = (parentMap[temporal_reference.reference] || []).concat root
            @mergeParentMaps(parentMap, @buildParentMap(dataCriteriaMap[temporal_reference.reference]))
      if root.children_criteria
        for child in root.children_criteria
          parentMap[child] = (parentMap[child] || []).concat root
          @mergeParentMaps(parentMap, @buildParentMap(dataCriteriaMap[child]))
    parentMap
  mergeParentMaps: (left, right) ->
    for key,value of right
      if (left[key])
        left[key] = left[key].concat right[key]
      else
        left[key] = right[key]
    left

  # Or counts are used to know when to turn an OR from green to red.  Once we negate all the true ors, we can switch to red
  calculateOrCounts: (rationale) ->
    orCounts = {}
    for code in Thorax.Models.Measure.allPopulationCodes
      if populationCriteria = @population.get(code)
        _.extend(orCounts, @calculateOrCountsRecursive(rationale, populationCriteria.preconditions))
    orCounts

  # recursively walk preconditions to count true values for child ORs moving down the tree
  calculateOrCountsRecursive: (rationale, preconditions) ->
    orCounts = {}
    return orCounts unless preconditions? && preconditions.length > 0
    for precondition in preconditions
      if (precondition.conjunction_code == 'atLeastOneTrue' && !precondition.negation)
        trueCount = 0
        if precondition.preconditions?.length > 0
          for child in precondition.preconditions
            if (child.preconditions)
              key = "precondition_#{child.id}"
            else
              key = child.reference
            trueCount += 1 if rationale[key]
        orCounts["precondition_#{precondition.id}"] = trueCount
      _.extend(orCounts, @calculateOrCountsRecursive(rationale, precondition.preconditions))
    return orCounts

  highlightPatientData: (dataCriteriaKey, populationCriteriaKey) ->
    matchingCodedEntries = @get('rationale')[dataCriteriaKey]?['results']
    if matchingCodedEntries
      console.log dataCriteriaKey
      index = hqmf.SpecificsManager.indexLookup[@measure.get('data_criteria')[dataCriteriaKey].source_data_criteria]
      goodElements = (row[index] for row in @get('finalSpecifics')[populationCriteriaKey]) if index
      for codedEntry in matchingCodedEntries
        type = (if goodElements && goodElements.indexOf(codedEntry.id) < 0 then "partial" else "valid")
        @patient.highlightCodedEntry(codedEntry.id, type)


class Thorax.Collections.Results extends Thorax.Collection
  model: Thorax.Models.Result
  initialize: (models, options) -> @parent = options?.parent
