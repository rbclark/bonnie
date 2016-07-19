class Thorax.Views.Matrix extends Thorax.Views.BonnieView

  template: JST['matrix']

  initialize: ->
    @collection.comparator = (m) -> if match = m.get('cms_id').match(/CMS([0-9]+)/) then parseInt(match[1]) else 0
    @collection.sort()
    @patients.comparator = (p) -> [p.get('last'), p.get('first')]
    @patients.sort()

  context: ->
    _(super).extend measures: @collection.populations().map (p) -> name: p.displayName(), hqmf_set_id: p.measure().get('hqmf_set_id')

  patientContext: (p) ->
    _(p.toJSON()).extend results: @collection.populations().map (m) -> m.calculate(p)


class Thorax.Views.MatrixCell extends Thorax.Views.BonnieView

  tagName: 'td'

  template: -> null # Empty template, everything is in the class name

  events:
    rendered: ->
      if @model.differenceFromExpected().has('match')
        title = "#{@model.population.displayName()} - #{@model.patient.get('last')}, #{@model.patient.get('first')}"
        content = JST['population_calculation_results'](patient: @model.patient.toJSON(), comparisons: @model.differenceFromExpected().get('comparisons'))
        @$el.popover trigger: 'hover', placement: 'bottom', container: 'body', title: title, html: true, content: content
    mouseover: ->
      @$el.addClass('highlight-box')
      @$el.parent().find('td.patient-name').addClass('highlight-font')
      @$el.closest('table').find("th.measure-#{@model.population.displayName()}").addClass('highlight-font')
    mouseout: ->
      @$el.removeClass('highlight-box')
      @$el.parent().find('td.patient-name').removeClass('highlight-font')
      @$el.closest('table').find("th.measure-#{@model.population.displayName()}").removeClass('highlight-font')
    click: ->
      @$el.popover 'destroy'
      $(".popover").remove() # Destroy doesn't seem to remove the popover, so remove it directly
      bonnie.navigate "measures/#{@model.measure.get('hqmf_set_id')}/patients/#{@model.patient.id}/edit", trigger: true
    model:
      change: -> @$el.addClass(@className())

  className: ->
    difference = @model.differenceFromExpected()
    return 'notcalculated link' if !difference.has('match') # Not yet calculated
    return 'irrelevent link' if difference.expected.attributes.IPP == undefined && difference.expected.attributes.STRAT == undefined #No expectations defined
    return 'strat link' if difference.get('match') && @model.get('STRAT') == 1
    return 'blank link' if difference.get('match') && @model.get('IPP') == 0 # Matches expectations, but not in IPP, so not noteworthy
    return 'ipp link' if difference.get('match') && @model.get('IPP') == 1 && difference.expected.attributes.DENOM == 0
    return 'denom link' if difference.get('match') && @model.get('DENOM') == 1 && @model.get('DENEX') == 0 &&  @model.get('DENEXCEP') == 0 && @model.get('NUMER') == 0
    return 'denex link' if difference.get('match') && @model.get('DENEX') == 1
    return 'denexcep link' if difference.get('match') && @model.get('DENEXCEP') == 1
    return 'numer link' if difference.get('match') && @model.get('NUMER') == 1
    return 'numex link' if difference.get('match') && @model.get('NUMEX') == 1
    return 'match link' if difference.get('match') # Matches expectations
    return 'problem link' # Doesn't match
