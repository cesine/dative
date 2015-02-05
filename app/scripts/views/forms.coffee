define [
  'backbone'
  './base'
  './form'
  './pagination-menu-top'
  './pagination-item-table'
  './../collections/forms'
  './../utils/paginator'
  './../utils/globals'
  './../templates/forms'
  'perfectscrollbar'
], (Backbone, BaseView, FormView, PaginationMenuTopView,
  PaginationItemTableView, FormsCollection, Paginator, globals,
  formsTemplate) ->

  # Forms View
  # -----------
  #
  # Displays a list of forms.

  class FormsView extends BaseView

    template: formsTemplate

    initialize: (options) ->
      @focusedElementIndex = null
      @formViews = []
      @renderedFormViews = []
      @renderedPaginationItemTableViews = []
      @fetchCompleted = false
      @lastFetched =
        serverType: ''
        serverName: ''
        fieldDBCorpusPouchname: ''
      @paginator = new Paginator()
      @paginationMenuTopView = new PaginationMenuTopView paginator: @paginator
      @applicationSettings = options.applicationSettings
      @activeFieldDBCorpus = options.activeFieldDBCorpus
      @getActiveServerType()
      @collection = new FormsCollection()
      @collection.applicationSettings = @applicationSettings
      @collection.activeFieldDBCorpus = @activeFieldDBCorpus
      @listenToEvents()

    events:
      'focus button, input, .ui-selectmenu-button, .dative-form-object':
        'rememberFocusedElement'
      'focus .dative-form-object': 'scrollToFocusedInput'
      'click .expand-all': 'expandAllForms'
      'click .collapse-all': 'collapseAllForms'
      'click .new-form': 'showNewFormView'
      'click .forms-browse-help': 'openFormsBrowseHelp'
      'keydown': 'keyboardShortcuts'

    # Tell the Help dialog to open itself and search for "browsing forms" and
    # scroll to the second match. WARN: this is brittle because if the help
    # HTML changes, then the second match may not be what we want
    openFormsBrowseHelp: ->
      Backbone.trigger(
        'helpDialog:toggle',
        searchTerm: 'browsing forms'
        scrollToIndex: 1
      )

    # These are the focusable elements in the forms browse interface.
    focusableSelector: 'button, input, .ui-selectmenu-button, .dative-form-object'

    expandAllForms: ->
      @listenToOnce Backbone, 'form:formExpanded', @restoreFocusAndScrollPosition
      Backbone.trigger 'formsView:expandAllForms'

    restoreFocusAndScrollPosition: ->
      @focusLastFocusedElement()
      @scrollToFocusedInput()

    collapseAllForms: ->
      @listenToOnce Backbone, 'form:formCollapsed', @restoreFocusAndScrollPosition
      Backbone.trigger 'formsView:collapseAllForms'

    showNewFormView: ->
      console.log 'You want to display the new form view'

    listenToEvents: ->
      @stopListening()
      @undelegateEvents()
      @delegateEvents()

      @listenTo Backbone, 'fetchAllFieldDBFormsStart', @fetchAllFormsStart
      @listenTo Backbone, 'fetchAllFieldDBFormsEnd', @fetchAllFormsEnd
      @listenTo Backbone, 'fetchAllFieldDBFormsSuccess', @fetchAllFormsSuccess

      @listenTo Backbone, 'fetchOLDFormsStart', @fetchAllFormsStart
      @listenTo Backbone, 'fetchOLDFormsEnd', @fetchAllFormsEnd
      @listenTo Backbone, 'fetchOLDFormsSuccess', @fetchAllFormsSuccess

      @listenTo @paginationMenuTopView, 'paginator:changeItemsPerPage', @changeItemsPerPage
      @listenTo @paginationMenuTopView, 'paginator:showFirstPage', @showFirstPage
      @listenTo @paginationMenuTopView, 'paginator:showLastPage', @showLastPage
      @listenTo @paginationMenuTopView, 'paginator:showPreviousPage', @showPreviousPage
      @listenTo @paginationMenuTopView, 'paginator:showNextPage', @showNextPage
      @listenTo @paginationMenuTopView, 'paginator:showThreePagesBack', @showThreePagesBack
      @listenTo @paginationMenuTopView, 'paginator:showTwoPagesBack', @showTwoPagesBack
      @listenTo @paginationMenuTopView, 'paginator:showOnePageBack', @showOnePageBack
      @listenTo @paginationMenuTopView, 'paginator:showOnePageForward', @showOnePageForward
      @listenTo @paginationMenuTopView, 'paginator:showTwoPagesForward', @showTwoPagesForward
      @listenTo @paginationMenuTopView, 'paginator:showThreePagesForward', @showThreePagesForward

    # The FormsView is here directly manipulating the GUI domain of the Pagination
    # Top Menu in order to implement some of these keyboard shortcuts. This seems
    # better than an overload of message passing, but we may want to change this
    # later.
    # WARN: TODO: @jrwdunham: some of these keyboard shortcuts should only work if
    # user-editable fields are *not* open. That is, we do not want "n" to bring us
    # to the next page if we are editing a form and type the character "n"
    # TODO: @jrwdunham @cesine: consider changing the shortcut keys: vim-style
    # conventions or arrow keys might be better. Alternatively (or in
    # addition), we could have these be user-customizable. 
    keyboardShortcuts: (event) ->
      if not event.ctrlKey
        switch event.which
          when 70 then @$('.first-page').click() # f
          when 80 then @$('.previous-page').click() # p
          when 78 then @$('.next-page').click() # n
          when 76 then @$('.last-page').click() # l
          when 40 then @$('.expand-all').click() # down arrow
          when 38 then @$('.collapse-all').click() # up arrow

    render: (taskId) ->
      context =
        pluralizeByNum: @utils.pluralizeByNum
        paginator: @paginator
      @$el.html @template(context)
      @$('.no-forms').hide()
      @spin()
      @matchHeights()
      @guify()
      @refreshHeader()
      @renderPaginationMenuTopView()
      if @weNeedToFetchFormsAgain()
        @fetchFormsToCollection()
      else
        @refreshPage()
      @listenToEvents()
      @perfectScrollbar()
      @setFocus()
      Backbone.trigger 'longTask:deregister', taskId
      @

    fetchFormsToCollection: ->
      if @getActiveServerType() is 'FieldDB'
        @collection.fetchAllFieldDBForms()
      else
        @collection.fetchOLDForms()

    renderPaginationMenuTopView: ->
      @paginationMenuTopView.setElement @$('div.dative-pagination-menu-top').first()
      @paginationMenuTopView.render paginator: @paginator
      @rendered @paginationMenuTopView

    fetchAllFormsStart: ->
      @fetchCompleted = false
      @spin 'fetching all forms'

    fetchAllFormsEnd: ->
      @fetchCompleted = true
      @stopSpin()

    fetchAllFormsSuccess: ->
      @saveFetchedMetadata()
      @getFormViews()
      @refreshPage()

    # Remember the server type (and corpus name) of the last fetch, so we don't needlessly
    # repeat it on future renderings.
    saveFetchedMetadata: ->
      @lastFetched.serverType = @getActiveServerType()
      @lastFetched.serverName = @getActiveServerName()
      @lastFetched.fieldDBCorpusPouchname = @getActiveServerFieldDBCorpusPouchname()

    getActiveServerType: ->
      globals.applicationSettings.get('activeServer').get 'type'

    getActiveServerName: ->
      globals.applicationSettings.get('activeServer').get 'name'

    getActiveServerFieldDBCorpusPouchname: ->
      if @getActiveServerType() is 'FieldDB'
        globals.applicationSettings.get 'activeFieldDBCorpus'
      else
        null

    # Returns false if we have already fetched these forms; prevents redundant
    # requests.
    weNeedToFetchFormsAgain: ->
      toFetch =
        serverType: @getActiveServerType()
        serverName: @getActiveServerName()
        fieldDBCorpusPouchname: @getActiveServerFieldDBCorpusPouchname()
      if _.isEqual(toFetch, @lastFetched) then false else true

    refreshPage: (options) ->
      @refreshHeader()
      @refreshPaginationMenuTop()
      @closeThenOpenCurrentPage options

    closeThenOpenCurrentPage: (options) ->
      hideMethod = 'hide'
      hideOptions =
        complete: =>
          @$('.dative-pagin-items').html ''
          @closeRenderedFormViews()
          @closeRenderedPaginationItemTableViews()
          @renderPage options
      if options?.hideEffect
        hideOptions.duration = @getAnimationDuration()
        hideMethod = options.hideEffect
      @$('.dative-pagin-items')[hideMethod] hideOptions

    getAnimationDuration: ->
      100
      #100 + (10 * @paginator.itemsDisplayed)

    closeRenderedFormViews: ->
      while @renderedFormViews.length
        formView = @renderedFormViews.pop()
        formView.close()
        @closed formView

    closeRenderedPaginationItemTableViews: ->
      while @renderedPaginationItemTableViews.length
        paginationItemTableView = @renderedPaginationItemTableViews.pop()
        paginationItemTableView.close()
        @closed paginationItemTableView

    refreshPaginationMenuTop: ->
      @paginationMenuTopView.render paginator: @paginator

    getFormViews: ->
      @collection.each (formModel) =>
        newFormView = new FormView
          model: formModel
          applicationSettings: @applicationSettings
        @formViews.push newFormView

    spinnerOptions: ->
      _.extend BaseView::spinnerOptions(), {top: '25%', left: '98%'}

    spin: (tooltipMessage) ->
      @$('#dative-page-header')
        .spin @spinnerOptions()
      if tooltipMessage
        console.log "have a message: #{tooltipMessage}"
        @$('#dative-page-header')
          .tooltip
            content: tooltipMessage
            position:
              my: "left+10 center"
              at: "right top+20"
              collision: "flipfit"
          .tooltip 'open'

    stopSpin: ->
      $header = @$('#dative-page-header')
      $header.spin false
      if $header.tooltip 'instance' then $header.tooltip 'destroy'

    # ISSUE: @jrwdunham: because the paginator buttons can become dis/enabled
    # based on the paginator state, the setFocus can behave erratically, since
    # it sets focus based on the remembered index of a jQuery matched set.
    setFocus: ->
      if @focusedElementIndex
        @focusLastFocusedElement()
      else
        @focusFirstForm()

    focusFirstButton: ->
      @$('button.ui-button').first().focus()

    focusFirstForm: ->
      @$('div.dative-form-object').first().focus()

    guify: ->

      @$('button').button().attr('tabindex', 0)

      @$('button.new-form')
        .button()
        .tooltip
          position:
            my: "right-10 center"
            at: "left center"
            collision: "flipfit"

      @$('button.expand-all')
        .button()
        .tooltip
          position:
            my: "right-45 center"
            at: "left center"
            collision: "flipfit"

      @$('button.collapse-all')
        .button()
        .tooltip
          position:
            my: "right-80 center"
            at: "left center"
            collision: "flipfit"

      @$('button.forms-browse-help')
        .button()
        .tooltip
          position:
            my: "left+10 center"
            at: "right center"
            collision: "flipfit"

    perfectScrollbar: ->
      @$('#dative-page-body')
        .perfectScrollbar()
        .scroll => @closeAllTooltips()

    # Render a page (pagination) of form views.
    renderPage: (options) ->
      @paginator._refresh() # TODO: NECESSARY?
      $formList = @$('.dative-pagin-items')
      for index in [@paginator.start..@paginator.end]
        formView = @formViews[index]
        if formView # formView may be undefined.
          formId = formView.model.get 'id'
          paginationItemTableView = new PaginationItemTableView
            formId: formId
            index: index + 1
          $formList.append paginationItemTableView.render().el
          formView.setElement @$("##{formId}")
          formView.render()
          @renderedFormViews.push formView
          @rendered formView
          @renderedPaginationItemTableViews.push paginationItemTableView
          @rendered paginationItemTableView
      @stopSpin()

      if options?.showEffect
        $formList[options.showEffect]
          duration: @getAnimationDuration()
          complete: =>
            @setFocus()
      else
        $formList.show()
        @setFocus()

    refreshHeader: ->
      if not @fetchCompleted
        @$('.no-forms').hide()
        @$('.pagination-info').hide()
        @$('button.expand-all').button 'disable'
        @$('button.collapse-all').button 'disable'
        @$('button.new-form').button 'disable'
        return
      @paginator.setItems @collection.length
      if @paginator.items is 0
        @$('.no-forms').show()
        @$('.pagination-info').hide()
        @$('button.expand-all').button 'disable'
        @$('button.collapse-all').button 'disable'
      else
        @$('.no-forms').hide()
        @$('.pagination-info').show()
        @$('button.expand-all').button 'enable'
        @$('button.collapse-all').button 'enable'
        if @paginator.start is @paginator.end
          @$('.form-range')
            .text "form #{@utils.integerWithCommas(@paginator.start + 1)}"
        else
          @$('.form-range').text ["forms",
            "#{@utils.integerWithCommas(@paginator.start + 1)}",
            "to",
            "#{@utils.integerWithCommas(@paginator.end + 1)}"].join ' '
        @$('.form-count').text @utils.integerWithCommas(@paginator.items)
        @$('.form-count-noun').text @utils.pluralizeByNum('form', @paginator.items)
        @$('.page-count').text @utils.integerWithCommas(@paginator.pages)
        @$('.page-count-noun').text @utils.pluralizeByNum('page', @paginator.pages)

    changeItemsPerPage: (newItemsPerPage) ->
      itemsDisplayedBefore = @paginator.itemsDisplayed
      @paginator.setItemsPerPage newItemsPerPage
      itemsDisplayedAfter = @paginator.itemsDisplayed
      if itemsDisplayedBefore isnt itemsDisplayedAfter
        @refreshPage
          hideEffect: 'fadeOut'
          showEffect: 'fadeIn'

    showFirstPage: ->
      pageBefore = @paginator.page
      @paginator.setPageToFirst()
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        @refreshPage
          hideEffect: 'fadeOut'
          showEffect: 'fadeIn'

    showPreviousPage: ->
      pageBefore = @paginator.page
      @paginator.setPageToPrevious()
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        @refreshPage
          hideEffect: 'fadeOut'
          showEffect: 'fadeIn'

    showNextPage: ->
      pageBefore = @paginator.page
      @paginator.setPageToNext()
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        @refreshPage
          hideEffect: 'fadeOut'
          showEffect: 'fadeIn'

    showLastPage: ->
      pageBefore = @paginator.page
      @paginator.setPageToLast()
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        @refreshPage
          hideEffect: 'fadeOut'
          showEffect: 'fadeIn'

    # Show a new page where `method` determines whether the new page is
    # behind or ahead of the current one and where `n` is the number of
    # pages behind or ahead.
    showPage: (n, method) ->
      pageBefore = @paginator.page
      @paginator[method] n
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        @refreshPage
          hideEffect: 'fadeOut'
          showEffect: 'fadeIn'

    showThreePagesBack: ->
      @showPage 3, 'decrementPage'

    showTwoPagesBack: ->
      @showPage 2, 'decrementPage'

    showOnePageBack: ->
      @showPage 1, 'decrementPage'

    showOnePageForward: ->
      @showPage 1, 'incrementPage'

    showTwoPagesForward: ->
      @showPage 2, 'incrementPage'

    showThreePagesForward: ->
      @showPage 3, 'incrementPage'

