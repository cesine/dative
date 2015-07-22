define [
  './input'
  './resource-as-row'
  './../models/resource'
  './../templates/resource-select-via-search-input'
  './../utils/globals'
], (InputView, ResourceAsRowView, ResourceModel,
  resourceSelectViaSearchInputTemplate, globals) ->

  # Resource Select Via Search Input View
  # -------------------------------------
  #
  # A view for selecting a particular resource (say, for a many-to-one
  # relation) by searching for it in a search input. This input should do some
  # "smart" search, i.e., try to understand what the user may be searching for.
  #
  # TODO/NOTE: this view assumes that the resource being searched/selected is
  # the file resource, specifically when looking for a parent file for a
  # subinterval-referencing file. This class should be generalized.

  class ResourceSelectViaSearchInputView extends InputView

    # Change these attributes in subclasses.
    resourceName: 'resource'
    resourceModelClass: ResourceModel
    resourceAsRowViewClass: ResourceAsRowView

    template: resourceSelectViaSearchInputTemplate

    refresh: (@context) ->
      @selectedValue()
      @resourceMediaViewRendered = false
      @render()

    initialize: (context) ->
      super context
      @resourceNamePlural = @utils.pluralize @resourceName
      @resourceNameCapitalized = @utils.capitalize @resourceName
      @resourceNamePluralCapitalized = @utils.capitalize @resourceNamePlural
      @searchResultsTableVisible = false
      @searchResultsCount = 0
      @selectedValue()

    selectedValue: ->
      if @context.value
        @selectedResourceModel = new @resourceModelClass(@context.value)
        @searchInterfaceVisible = false
        @resourceMediaViewVisible = true
      else
        @searchInterfaceVisible = true
        @resourceMediaViewVisible = false

    render: ->
      @context.resourceNameHuman = @utils.snake2regular @context.attribute
      @context.resourceNameHumanCapitalized =
        (@utils.capitalize(w) for w in @context.resourceNameHuman.split(' ')).join ' '
      super
      @buttonify()
      @tooltipify()
      @renderHeaderView()
      @searchResultsTable()
      @searchInterfaceVisibility()
      if @selectedResourceModel
        if @resourceMediaViewRendered
          @showResourceMediaView()
        else
          @renderResourceMediaView()
      else
        @resourceMediaViewVisibility()
      @

    searchResultsTable: ->
      @$('.resource-results-via-search-table-wrapper')
        .css 'border-color': @constructor.jQueryUIColors().defBo
      @searchResultsTableVisibility()

    resourceMediaView: null
    resourceMediaViewClass: null
    resourceMediaViewRendered: false
    selectedResourceModel: null

    closeCurrentResourceMediaView: ->
      if @resourceMediaView
        @resourceMediaView.close()
        @closed @resourceMediaView

    renderResourceMediaView: ->
      if @resourceMediaViewClass
        @closeCurrentResourceMediaView()
        @resourceMediaView = new @resourceMediaViewClass
          model: @selectedResourceModel
        $container = @$('.selected-resource-display-container').first()
        @resourceMediaView.setElement $container
        @resourceMediaView.render()
        @rendered @resourceMediaView
        @listenToResourceMediaView()
        @resourceMediaViewVisible = true
        @resourceMediaViewRendered = true
        $container.css 'border-color': @constructor.jQueryUIColors().defBo
        @resourceMediaViewVisibility()

    listenToResourceMediaView: ->
      @listenTo @resourceMediaView, 'deselectAsParentFile', @deselectCurrentlySelectedResourceModel
      @listenTo @resourceMediaView, 'setAttribute', @setAttribute

    setAttribute: (attr, val) ->
      @model.trigger 'setAttribute', attr, val

    deselectCurrentlySelectedResourceModel: ->
      @model.set 'MIME_type', ''
      @model.set 'parent_file', null
      @selectedResourceModel = null
      @trigger 'validateMe'
      if @searchResultsCount > 0 then @showSearchResultsTableAnimate()
      @showSearchInterfaceAnimate (=> @focusAndSelectSearchTerm())
      @hideResourceMediaViewAnimateCheck(=> @closeCurrentResourceMediaView())

    focusAndSelectSearchTerm: ->
      @$('[name=search-term]').first().focus().select()

    # Set the `parent_file` attribute of our model to the model of the
    # passed-in `resourceAsRowView`
    selectResourceAsRowView: (resourceAsRowView) ->
      @model.set 'MIME_type', resourceAsRowView.model.get('MIME_type')
      @model.set 'parent_file', resourceAsRowView.model.attributes
      @selectedResourceModel = resourceAsRowView.model
      @model.trigger 'setAttribute', 'start', 0
      @trigger 'validateMe'
      @hideSearchResultsTableAnimate()
      @hideSearchInterfaceAnimate()
      @renderResourceMediaView()
      @$('button.deselect-parent-file').first().focus().select()
      @$('audio, video')
        .on 'loadedmetadata', ((event) => @metadataLoaded event)

    tooltipify: ->
      @$('.dative-tooltip')
        .tooltip position: @tooltipPositionLeft('-200')

    events:
      'click .perform-search': 'performSearch'

    listenToEvents: ->
      super
      @listenTo @model, 'searchSuccess', @searchSuccess
      @listenTo @model, 'searchStart', @searchStart
      @listenTo @model, 'searchEnd', @searchEnd
      @listenTo @model, 'searchFail', @searchFail

    itemsPerPage: 100

    resourceAsRowViews: []

    closeResourceAsRowViews: ->
      while @resourceAsRowViews.length
        view = @resourceAsRowViews.pop()
        view.close()
        @closed view

    getSearchResultsHeader: ->
      header = ['<div class="resource-as-row-row">']
      if @resourceAsRowViewClass::orderedAttributes
        iterator = @resourceAsRowViewClass::orderedAttributes
      else
        iterator = _.keys (new @resourceModelClass()).attributes
      for attribute in iterator
        header.push "<div class='resource-as-row-cell
          resource-as-row-attr-#{attribute}'
          >#{@utils.snake2regular attribute}</div>"
      header.push '</div>'
      header.join ''

    searchSuccess: (responseJSON) ->
      @showSearchResultsTableAnimateCheck()
      @closeResourceAsRowViews()
      @searchResultsCount = @reportMatchesFound responseJSON
      if @searchResultsCount > 0
        @$('div.resource-results-via-search-table')
          .html @getSearchResultsRows(responseJSON)
          .scrollLeft 0
        @$('button.select').first().focus()

    reportMatchesFound: (responseJSON) ->
      count = responseJSON.paginator.count
      itemsPerPage = responseJSON.paginator.items_per_page
      noun = if count is 1 then 'match' else 'matches'
      @$('span.results-count').text "#{count} #{noun}"
      if count > 0
        showing = if (count < itemsPerPage) then count else itemsPerPage
        @$('span.results-showing-count').text "showing #{showing}"
      count

    renderHeaderView: ->
      headerObject = {}
      for attr in @resourceAsRowViewClass::orderedAttributes
        headerObject[attr] = @utils.snake2regular attr
      @headerModel = new @resourceModelClass headerObject
      @headerView = new @resourceAsRowViewClass
        model: @headerModel
        isHeaderRow: true
      @headerView.render()
      @rendered @headerView

    getSearchResultsRows: (responseJSON) ->
      fragment = document.createDocumentFragment()
      fragment.appendChild @headerView.el
      for modelObject in responseJSON.items
        resourceModel = new @resourceModelClass modelObject
        resourceAsRowView = new @resourceAsRowViewClass
          model: resourceModel
          query: @query
        @resourceAsRowViews.push resourceAsRowView
        resourceAsRowView.render()
        @rendered resourceAsRowView
        @listenToResourceAsRow resourceAsRowView
        fragment.appendChild resourceAsRowView.el
      fragment

    listenToResourceAsRow: (resourceAsRowView) ->
      @listenTo resourceAsRowView, 'selectMe', @selectResourceAsRowView

    onClose: ->
      @$('audio, video').off 'loadedmetadata'
      @resourceMediaViewRendered = false

    metadataLoaded: (event) ->
      @model.trigger 'setAttribute', 'end', event.currentTarget.duration

    searchFail: (errorMessage) ->
      Backbone.trigger 'fileSearchFail', errorMessage

    searchStart: ->
      @disableInterface()
      @spin()

    searchEnd: ->
      @enableInterface()
      @stopSpin()

    disableInterface: ->
      @$('button').button 'disable'
      @$('input').prop 'disabled', true

    enableInterface: ->
      @$('button').button 'enable'
      @$('input').prop 'disabled', false

    spinnerOptions: ->
      options = super
      options.top = '50%'
      options.left = '130%'
      options.color = @constructor.jQueryUIColors().defCo
      options

    spin: -> @$('button.perform-search').first().spin @spinnerOptions()

    stopSpin: -> @$('button.perform-search').first().spin false

    getGlobalDataAttribute: -> "search#{@resourceNamePluralCapitalized}Data"

    performSearch: ->
      searchTerm = @$('[name=search-term]').val()
      if globals[@getGlobalDataAttribute()]
        paginator =
          page: 1
          items_per_page: @itemsPerPage
        @query = @getSmartQuery searchTerm
        @model.search @query, paginator
      else
        @listenToOnce @model,
          "getNew#{@resourceNameCapitalized}SearchDataSuccess",
          @getNewResourceSearchDataSuccess
        @listenToOnce @model, "getNew#{@resourceNameCapitalized}SearchDataFail",
          @getNewResourceSearchDataFail
        @model.getNewSearchData()

    # These are the `[<attribute]`s or `[<attribute>, <subattribute>]`s that we
    # "smartly" search over.
    # TODO: consider fixing the following. You can't search files based on the
    # translations of the forms that they are associated to. This is a failing
    # of the OLD web service search interface. Adding this extra level of depth
    # would be useful here and elsewhere ...
    smartStringSearchableFileAttributes: [
      ['id']
      ['filename']
      ['MIME_type']
      ['name']
      ['url']
      ['description']
      ['forms', 'transcription']
      ['tags', 'name']
    ]

    # Returns `true` if `searchTerms` is an array containing a string that only
    # contains digits; here we assume the user is searching for a numeric id.
    isIdSearch: (searchTerms) ->
      searchTerms.length is 1 and searchTerms[0].match /^[0-9]+$/

    getAudioVideoMIMETypes: ->
      a = globals.applicationSettings.get 'allowedFileTypes'
      (t for t in a when t[...5] in ['audio', 'video'])

    isAudioVideoFilterExpression: ->
      [
        @resourceNameCapitalized
        'MIME_type'
        'in'
        @getAudioVideoMIMETypes()
      ]

    hasAFilenameFilterExpression: ->
      [
        @resourceNameCapitalized
        'filename'
        '!='
        null
      ]

    # Return a query object for intelligently searching over (OLD) file
    # resources, given the string `searchTerm`. Here we try to guess what the
    # user probably wants their search expression to do.
    getSmartQuery: (searchTerm) ->
      searchTerms = searchTerm.split /\s+/
      order_by = [@resourceNameCapitalized, 'id', 'desc']
      if @isIdSearch searchTerms
        filter = ['and', [
          @isAudioVideoFilterExpression(),
          @hasAFilenameFilterExpression(),
          [@resourceNameCapitalized, 'id', '=', parseInt(searchTerms[0])]]]
      else
        filter = @getGeneralFileSearch searchTerms
      order_by: order_by
      filter: filter

    # Return a search filter over File resources that returns all files such
    # that all of the search terms in `searchTerms` match (substring-wise) at
    # least one of the "string-searchable" file attributes listed in
    # `@smartStringSearchableFileAttributes`.
    getGeneralFileSearch: (searchTerms) ->
      filter = ['and']
      complement = [
        @isAudioVideoFilterExpression()
        @hasAFilenameFilterExpression()
      ]
      for searchTerm in searchTerms
        conjunct = ['or']
        subcomplement = []
        for attributeSet in @smartStringSearchableFileAttributes
          subfilter = [@resourceNameCapitalized]
          for attribute in attributeSet
            subfilter.push attribute
          subfilter.push 'like'
          subfilter.push "%#{searchTerm}%"
          subcomplement.push subfilter
        conjunct.push subcomplement
        complement.push conjunct
      filter.push complement
      filter

    getNewResourceSearchDataSuccess: (data) ->
      globals[@getGlobalDataAttribute()] = data
      @performSearch()

    getNewResourceSearchDataFail: (error) ->
      console.log "Sorry, we were not able to retrieve the data for creating a
        search over #{@resourceNamePlural}"

    # Search Results Table
    ############################################################################

    # Make the search results table visible, or not, depending on state.
    searchResultsTableVisibility: ->
      if @searchResultsTableVisible
        @showSearchResultsTable()
      else
        @hideSearchResultsTable()

    showSearchResultsTable: ->
      @searchResultsTableVisible = true
      @$('.resource-results-via-search-table-wrapper').first().show()

    hideSearchResultsTable: ->
      @searchResultsTableVisible = false
      @$('.resource-results-via-search-table-wrapper').first().hide()

    toggleSearchResultsTable: ->
      if @searchResultsTableVisible
        @hideSearchResultsTable()
      else
        @showSearchResultsTable()

    showSearchResultsTableAnimateCheck: ->
      if @$('.resource-results-via-search-table-wrapper').is ':hidden'
        @showSearchResultsTableAnimate()

    showSearchResultsTableAnimate: ->
      @searchResultsTableVisible = true
      @$('.resource-results-via-search-table-wrapper').first().slideDown()

    hideSearchResultsTableAnimate: ->
      @searchResultsTableVisible = false
      @$('.resource-results-via-search-table-wrapper').first().slideUp()

    toggleSearchResultsTableAnimate: ->
      if @searchResultsTableVisible
        @hideSearchResultsTableAnimate()
      else
        @showSearchResultsTableAnimate()


    # Search Interface
    ############################################################################

    # Make the search interface visible, or not, depending on state.
    searchInterfaceVisibility: ->
      if @searchInterfaceVisible
        @showSearchInterface()
      else
        @hideSearchInterface()

    toggleSearchInterface: ->
      if @searchInterfaceVisible
        @hideSearchInterface()
      else
        @showSearchInterface()

    toggleSearchInterfaceAnimate: ->
      if @searchInterfaceVisible
        @hideSearchInterfaceAnimate()
      else
        @showSearchInterfaceAnimate()

    hideSearchInterfaceAnimate: ->
      @searchInterfaceVisible = false
      @$('.resource-select-via-search-interface').first().slideUp()

    showSearchInterfaceAnimate: (complete=->) ->
      @searchInterfaceVisible = true
      @$('.resource-select-via-search-interface').first().slideDown
        complete: complete

    hideSearchInterface: (complete=->) ->
      @searchInterfaceVisible = false
      @$('.resource-select-via-search-interface').first().hide
        complete: complete

    showSearchInterface: ->
      @searchInterfaceVisible = true
      @$('.resource-select-via-search-interface').first().show()


    # Resource Media View
    # NOTE: this presumes that the resource being searched here is files ...
    ############################################################################

    # Make the search results table visible, or not, depending on state.
    resourceMediaViewVisibility: ->
      if @resourceMediaViewVisible
        @showResourceMediaView()
      else
        @hideResourceMediaView()

    showResourceMediaView: ->
      @resourceMediaViewVisible = true
      @$('.selected-resource-display-container').first().show()

    hideResourceMediaView: ->
      @resourceMediaViewVisible = false
      @$('.selected-resource-display-container').first().hide()

    toggleResourceMediaView: ->
      if @resourceMediaViewVisible
        @hideResourceMediaView()
      else
        @showResourceMediaView()

    showResourceMediaViewAnimateCheck: ->
      if @$('.selected-resource-display-container').is ':hidden'
        @showResourceMediaViewAnimate()

    showResourceMediaViewAnimate: ->
      @resourceMediaViewVisible = true
      @$('.selected-resource-display-container').first().slideDown()

    hideResourceMediaViewAnimate: (complete=->) ->
      @resourceMediaViewVisible = false
      @$('.selected-resource-display-container').first().slideUp
        complete: complete

    hideResourceMediaViewAnimateCheck: (complete=->) ->
      if @$('.selected-resource-display-container').is ':visible'
        @hideResourceMediaViewAnimate complete

    toggleResourceMediaViewAnimate: ->
      if @resourceMediaViewVisible
        @hideResourceMediaViewAnimate()
      else
        @showResourceMediaViewAnimate()
