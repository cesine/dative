define [
  'backbone'
  './base'
  './form'
  './exporter-dialog'
  './pagination-menu-top'
  './pagination-item-table'
  './../collections/forms'
  './../models/form'
  './../utils/paginator'
  './../utils/globals'
  './../templates/forms'
  'perfectscrollbar'
], (Backbone, BaseView, FormView, ExporterDialogView,
  PaginationMenuTopView, PaginationItemTableView, FormsCollection, FormModel,
  Paginator, globals, formsTemplate) ->

  # Forms View
  # -----------
  #
  # Displays a list of forms for browsing (with pagination).
  #
  # Also contains a model-less FormView instance for creating new forms
  # within the forms browse interface.
  #
  # Note that this view accommodates both client-side pagination for FieldDB
  # backends and server-side pagination for OLD ones. That is, with FieldDB,
  # all forms are fetched upon first render and pagination involves displaying
  # certain sets of already-fetched forms. With the OLD, a new fetch is
  # performed whenever the pagination parameters change.

  class FormsView extends BaseView

    template: formsTemplate

    initialize: (options) ->
      @getGlobalsFormsDisplaySettings()
      @focusedElementIndex = null
      @formViews = [] # holds a FormView instance for each FormModel in FormsCollection
      @renderedFormViews = [] # references to the FormView instances that are rendered
      @weShouldFocusFirstAddViewInput = false # AppView sets this to True when you click Forms > Add
      @renderedPaginationItemTableViews = [] # Each form view is in a 1-row/2-cell table where cell 1 is the index+1, e.g., (1), (2), etc.
      @fetchCompleted = false
      @fetchOLDFormsLastPage = false # This is set to true when we want to fetch the last OLD page immediately after fetching the first one.
      @lastFetched = # We store this to help us prevent redundant requests to the server for all forms.
        serverType: ''
        serverName: ''
        fieldDBCorpusPouchname: ''
      @paginator = new Paginator page=1, items=0, itemsPerPage=@itemsPerPage
      @paginationMenuTopView = new PaginationMenuTopView paginator: @paginator # This handles the UI for the items-per-page select, the first, prevous, next buttons, etc.
      @collection = new FormsCollection()
      @newFormView = @getNewFormView()
      @exporterDialog = new ExporterDialogView()
      @newFormViewVisible = false
      @listenToEvents()

    events:
      'focus input, textarea, .ui-selectmenu-button, button, .ms-container': 'inputFocused'
      'focus .dative-form-object': 'formFocused'
      'click .expand-all': 'expandAllForms'
      'click .collapse-all': 'collapseAllForms'
      'click .new-form': 'showNewFormViewAnimate'
      'click .forms-browse-help': 'openFormsBrowseHelp'
      'click .toggle-all-labels': 'toggleAllLabels'
      'keydown': 'keyboardShortcuts'
      'keyup': 'keyup'
      # @$el is enclosed in top and bottom invisible divs. These allow us to
      # close-circuit the tab loop and keep focus in the view.
      'focus .focusable-top':  'focusLastElement'
      'focus .focusable-bottom':  'focusFirstElement'

    render: (taskId) ->
      @html()
      @matchHeights()
      @guify()
      @refreshHeader()
      @renderPaginationMenuTopView()
      @renderNewFormView()
      @renderExporterDialogView()
      @newFormViewVisibility()
      if @weNeedToFetchFormsAgain()
        @fetchFormsToCollection()
      else
        @refreshPage()
      @listenToEvents()
      @setFocus()
      Backbone.trigger 'longTask:deregister', taskId
      @

    renderExporterDialogView: ->
      @exporterDialog.setElement(@$('#exporter-dialog-container'))
      @exporterDialog.render()
      @rendered @exporterDialog

    html: ->
      @$el.html @template
        pluralizeByNum: @utils.pluralizeByNum
        paginator: @paginator

    listenToEvents: ->
      super

      @listenTo Backbone, 'fetchAllFieldDBFormsStart', @fetchAllFormsStart
      @listenTo Backbone, 'fetchAllFieldDBFormsEnd', @fetchAllFormsEnd
      @listenTo Backbone, 'fetchAllFieldDBFormsFail', @fetchAllFormsFail
      @listenTo Backbone, 'fetchAllFieldDBFormsSuccess', @fetchAllFormsSuccess

      @listenTo Backbone, 'fetchOLDFormsStart', @fetchAllFormsStart
      @listenTo Backbone, 'fetchOLDFormsEnd', @fetchAllFormsEnd
      @listenTo Backbone, 'fetchOLDFormsFail', @fetchAllFormsFail
      @listenTo Backbone, 'fetchOLDFormsSuccess', @fetchOLDFormsSuccess

      @listenTo Backbone, 'destroyOLDFormSuccess', @destroyOLDFormSuccess
      @listenTo Backbone, 'duplicateForm', @duplicateForm
      @listenTo Backbone, 'duplicateFormConfirm', @duplicateFormConfirm

      @listenTo Backbone, 'updateOLDFormFail', @scrollToFirstValidationError
      @listenTo Backbone, 'addOLDFormFail', @scrollToFirstValidationError

      @listenTo Backbone, 'openExporterDialog', @openExporterDialog

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

      @listenToNewFormView()

    listenToNewFormView: ->
      @listenTo @newFormView, 'newFormView:hide', @hideNewFormViewAnimate
      @listenTo @newFormView.model, 'addOLDFormSuccess', @newFormAdded

    scrollToFirstValidationError: (error, formModel) ->
      if formModel.id
        console.log 'we have an id'
        selector = "##{formModel.cid} .dative-field-validation-container"
      else
        console.log 'we DONT have an id'
        selector = ".new-form-view .dative-field-validation-container"
      $firstValidationError = @$(selector).filter(':visible').first()
      if $firstValidationError then @scrollToElement $firstValidationError

    # Get the global Dative application settings relevant to displaying a form.
    getGlobalsFormsDisplaySettings: ->
      defaults =
        itemsPerPage: 10
        primaryDataLabelsVisible: false
        allFormsExpanded: false
      try
        formsDisplaySettings = globals.applicationSettings.get 'formsDisplaySettings'
        _.extend defaults, formsDisplaySettings
      for key, value of defaults
        @[key] = value

    # Instantiate and return a new `FormView` instance. Note that even though
    # we pass the collection to the form view's model, the collection will not
    # contain that model.
    getNewFormView: (newFormModel) ->
      newFormModel = newFormModel or new FormModel(collection: @collection)
      new FormView
        headerTitle: 'New Form'
        model: newFormModel
        primaryDataLabelsVisible: @primaryDataLabelsVisible
        expanded: @allFormsExpanded

    # This is called when the 'addOLDFormSuccess' has been triggered, i.e.,
    # when a new form has been successfully created on the server.
    newFormAdded: (formModel) ->
      newFormShouldBeOnCurrentPage = @newFormShouldBeOnCurrentPage()
      # 1. Make the new form widget disappear.
      @hideNewFormViewAnimate()

      # 2. refresh the pagination stuff (necessarily changes)
      @paginator.setItems (@paginator.items + 1)
      @refreshHeader()
      @refreshPaginationMenuTop()

      # 3. If the new form should be displayed on the current page, then do that.
      Backbone.trigger 'addOLDFormSuccess', formModel
      if newFormShouldBeOnCurrentPage
        @addNewFormViewToPage()
      else
        @closeNewFormView()

      # 4. create a new new form widget but don't display it.
      # TODO: maybe the new new form view *should* be displayed ...
      @newFormViewVisible = false
      @newFormView = @getNewFormView()
      @renderNewFormView()
      @newFormViewVisibility()
      @listenToNewFormView()

    destroyOLDFormSuccess: (formModel) ->
      @paginator.setItems (@paginator.items - 1)
      @refreshHeader()
      @refreshPaginationMenuTop()
      destroyedFormView = _.findWhere @renderedFormViews, {model: formModel}
      if destroyedFormView
        destroyedFormView.$el.slideUp()
      @fetchOLDFormsPageToCollection()

    # Returns true if a new form should be on the currently displayed page.
    newFormShouldBeOnCurrentPage: ->
      itemsDisplayedCount = (@paginator.end - @paginator.start) + 1
      if itemsDisplayedCount < @paginator.itemsPerPage then true else false

    # Add the new form view to the set of paginated form views.
    # This entails adding the new form view's model to the collection
    # and then rendering it and adding it to the DOM.
    addNewFormViewToPage: ->
      addedFormView = new FormView
        model: @newFormView.model
        primaryDataLabelsVisible: @primaryDataLabelsVisible
        expanded: @allFormsExpanded
      @collection.add addedFormView.model
      @renderFormView addedFormView, @paginator.end

    # Keyboard shortcuts for the forms view.
    # Note that the FormsView is listening to events on parts of the DOM that are
    # more properly the domain of the Pagination Top Menu subview.
    # TODO: @jrwdunham @cesine: consider changing the shortcut keys: vim-style
    # conventions or arrow keys might be better. Alternatively (or in
    # addition), we could have these be user-customizable.
    keyboardShortcuts: (event) ->
      if not @addUpdateFormWidgetHasFocus()
        if not event.ctrlKey and not event.metaKey and not event.altKey
          switch event.which
            when 70 then @$('.first-page').click() # f
            when 80 then @$('.previous-page').click() # p
            when 78 then @$('.next-page').click() # n
            when 76 then @$('.last-page').click() # l
            when 40 # down arrow
              if not @itemsPerPageSelectHasFocus()
                @$('.expand-all').click()
            when 38 # up arrow
              if not @itemsPerPageSelectHasFocus()
                @$('.collapse-all').click()
            when 65 then @toggleNewFormViewAnimate() # a
            when 32 # spacebar goes to next form view, shift+spacebar goes to previous.
              if event.shiftKey
                @focusPreviousFormView event
              else
                @focusNextFormView event

    # Return the (jQuery-wrapped) form view <div> that encloses `$element`, if exists.
    getEnclosingFormViewDiv: ($element) ->
      if $element.hasClass '.dative-form-object'
        $element
      else if $element.closest('.dative-form-object').first()
        $element.closest('.dative-form-object').first()
      else
        null

    # Get the next (below) form view, if there is one; null otherwise.
    getNextFormViewDiv: ($formViewDiv) ->
      $nextFormViewDiv = $formViewDiv
        .closest('.dative-pagin-item')
        .next()
        .find('.dative-form-object')
      if $nextFormViewDiv then $nextFormViewDiv else null

    # Get the previous (above) form view, if there is one; null otherwise.
    getPreviousFormViewDiv: ($formViewDiv) ->
      $nextFormViewDiv = $formViewDiv
        .closest('.dative-pagin-item')
        .prev()
        .find('.dative-form-object')
      if $nextFormViewDiv then $nextFormViewDiv else null

    # Focus the next (below) form view, or the first one if we're at the top.
    focusNextFormView: (event) ->
      $enclosingFormViewDiv = @getEnclosingFormViewDiv @$(event.target)
      if $enclosingFormViewDiv.length
        $nextFormViewDiv = @getNextFormViewDiv $enclosingFormViewDiv
        @stopEvent event
        if $nextFormViewDiv.length
          $nextFormViewDiv.focus()
        else
          @focusFirstForm()

    # Focus the previous (above) form view, or the last one if we're at the top.
    focusPreviousFormView: (event) ->
      $enclosingFormViewDiv = @getEnclosingFormViewDiv @$(event.target)
      if $enclosingFormViewDiv.length
        $previousFormViewDiv = @getPreviousFormViewDiv $enclosingFormViewDiv
        @stopEvent event
        if $previousFormViewDiv.length
          $previousFormViewDiv.focus()
        else
          @focusLastForm()

    # Returns true if the "items per page" selectmenu in the Pagination Top
    # Menu view has focus; we don't want the expand/collapse shortcuts to
    # be triggered when we're using the arrow keys to change the number of
    # forms being displayed.
    itemsPerPageSelectHasFocus: ->
      @$('.ui-selectmenu-button.items-per-page').is ':focus'

    formFocused: (event) ->
      if @$(event.target).hasClass 'dative-form-object'
        @rememberFocusedElement event
        $element = @$ event.target
        @scrollToScrollableElement $element

    inputFocused: (event) ->
      @stopEvent event
      @rememberFocusedElement event

    keyup: (event) ->
      if event.which is 9
        $element = @$ event.target
        @scrollToScrollableElement $element

    scrollToScrollableElement: ($element) ->
      if (not $element.hasClass('ui-selectmenu-button')) and
      (not $element.hasClass('ms-list')) and
      (not $element.hasClass('hasDatepicker'))
        @scrollToElement $element

    # Tell the Help dialog to open itself and search for "browsing forms" and
    # scroll to the second match. WARN: this is brittle because if the help
    # HTML changes, then the second match may not be what we want.
    openFormsBrowseHelp: ->
      Backbone.trigger(
        'helpDialog:openTo',
        searchTerm: 'browsing forms'
        scrollToIndex: 1
      )

    # These are the focusable elements in the forms browse interface. See
    # BaseView for use of this attribute.
    focusableSelector: 'textarea, button, input, .ui-selectmenu-button,
      .dative-form-object'

    restoreFocusAndScrollPosition: ->
      @focusLastFocusedElement()
      @scrollToFocusedInput()

    # Toggle all primary data labels. Responds to `.toggle-all-labels` button.
    toggleAllLabels: ->
      if @primaryDataLabelsVisible
        @hideAllLabels()
      else
        @showAllLabels()

    # Tell all rendered forms to show their primary data labels. (Also tell
    # all un-rendered form views to show their labels when they do render.)
    showAllLabels: ->
      @primaryDataLabelsVisible = true
      @setToggleAllLabelsButtonStateOpen()
      @tellFormSubviewsToShowLabels()
      Backbone.trigger 'formsView:showAllLabels'

    # Tell all rendered forms to hide their primary data labels. (Also tell
    # all un-rendered form views to hide their labels when they do render.)
    hideAllLabels: ->
      @primaryDataLabelsVisible = false
      @setToggleAllLabelsButtonStateClosed()
      @tellFormSubviewsToHideLabels()
      Backbone.trigger 'formsView:hideAllLabels'

    # Make the "toggle all labels button" match view state.
    setToggleAllLabelsButtonState: ->
      if @primaryDataLabelsVisible
        @setToggleAllLabelsButtonStateOpen()
      else
        @setToggleAllLabelsButtonStateClosed()

    # Set "toggle all labels" button to state closed.
    setToggleAllLabelsButtonStateClosed: ->
      @$('.toggle-all-labels')
        .find 'i.fa'
          .removeClass 'fa-toggle-on'
          .addClass 'fa-toggle-off'
          .end()
        .button()
        .tooltip
          items: 'button'
          content: 'form labels are off; click here to turn them on'

    # Set "toggle all labels" button to state open.
    setToggleAllLabelsButtonStateOpen: ->
      @$('.toggle-all-labels')
        .find 'i.fa'
          .removeClass 'fa-toggle-off'
          .addClass 'fa-toggle-on'
          .end()
        .button()
        .tooltip
          items: 'button'
          content: 'form labels are on; click here to turn them off'

    # Tell all rendered forms to expand themselves; listen for one notice of
    # expansion from a form view and respond by restoring the focus and scroll
    # position. (Also tell all un-rendered form views to be expanded when they
    # do render.)
    expandAllForms: ->
      @allFormsExpanded = true
      @tellFormSubviewsToBeExpanded()
      @listenToOnce Backbone, 'form:formExpanded', @restoreFocusAndScrollPosition
      Backbone.trigger 'formsView:expandAllForms'

    # Tell all rendered forms to collapse themselves; listen for one notice of
    # collapse from a form view and respond by restoring the focus and scroll
    # position. (Also tell all un-rendered form views to be collapsed when they
    # do render.)
    collapseAllForms: ->
      @allFormsExpanded = false
      @tellFormSubviewsToBeCollapsed()
      @focusEnclosingFormView()
      @listenToOnce Backbone, 'form:formCollapsed', @restoreFocusAndScrollPosition
      Backbone.trigger 'formsView:collapseAllForms'

    # FieldDB form subviews all already exist, so we have to tell them to now be
    # collapsed by default.
    tellFormSubviewsToBeCollapsed: ->
      if @getActiveServerType() is 'FieldDB'
        for formView in @formViews
          formView.expanded = false
          formView.effectuateExpanded()

    # FieldDB form subviews all already exist, so we have to tell them to now be
    # expanded by default.
    tellFormSubviewsToBeExpanded: ->
      if @getActiveServerType() is 'FieldDB'
        for formView in @formViews
          formView.expanded = true
          formView.effectuateExpanded()

    # FieldDB form subviews all already exist, so we have to tell them to now
    # hide their primary data labels by default.
    tellFormSubviewsToHideLabels: ->
      if @getActiveServerType() is 'FieldDB'
        for formView in @formViews
          formView.primaryDataLabelsVisible = false

    # FieldDB form subviews all already exist, so we have to tell them to now
    # show their primary data labels by default.
    tellFormSubviewsToShowLabels: ->
      if @getActiveServerType() is 'FieldDB'
        for formView in @formViews
          formView.primaryDataLabelsVisible = true

    # Sets focus to the FormView div that contains the focused control. This is
    # necessary so that we can restore scroll position after a collapse-all
    # request wherein a previously focused control will become hidden and thus
    # unfocusable.
    focusEnclosingFormView: ->
      $focusedElement = @$ ':focus'
      if $focusedElement
        $focusedElement.closest('.dative-form-object').first().focus()

    # Tell the collection to fetch forms from the server and add them to itself.
    # Only `@render` calls this. Note that with a FieldDB backend we fetch
    # everything but with an OLD backend we just fetch the forms for the
    # current pagination page, i.e., we use the OLD's server-side pagination
    # feature.
    # Note that setting `fetchOLDFormsLastPage` to `true` will cause
    # `@fetchOLDFormsSuccess` to immediately make a second request for the last
    # page of forms. This is the only way to get the last page of forms from
    # the OLD via its current API; that is, you first have to make a vacuous
    # request in order to get the form count so that you know what the last
    # page is.
    fetchFormsToCollection: ->
      if @getActiveServerType() is 'FieldDB'
        @collection.fetchAllFieldDBForms()
      else
        @fetchOLDFormsLastPage = true
        @fetchOLDFormsPageToCollection()

    # Get a page of forms from an OLD web service.
    # Note that when the OLD is the server, the forms collection simply holds
    # one page at a time; that is, the collection is emptied and refilled on
    # each pagination action, hence the `.reset()` call here.
    fetchOLDFormsPageToCollection: ->
      @collection.reset()
      @collection.fetchOLDForms @paginator

    # Render the pagination top menu view. This is the row of buttons for controlling
    # the visible pagination page and how many items are visible per page.
    renderPaginationMenuTopView: ->
      @paginationMenuTopView.setElement @$('div.dative-pagination-menu-top').first()
      @paginationMenuTopView.render paginator: @paginator
      @rendered @paginationMenuTopView

    # Render the Add a Form view.
    renderNewFormView: ->
      @newFormView.setElement @$('.new-form-view').first()
      @newFormView.render()
      @rendered @newFormView

    # Close the Add a Form view.
    closeNewFormView: ->
      @newFormView.close()
      @closed @newFormView

    ############################################################################
    # Respond to `@collection`-issued events related to the "fetch forms" task.
    ############################################################################

    fetchAllFormsStart: ->
      @fetchCompleted = false
      @spin()

    fetchAllFormsEnd: ->
      @fetchCompleted = true

    fetchAllFormsFail: (reason) ->
      @stopSpin()
      console.log 'fetchAllFormsFail'
      console.log reason
      @$('.no-forms')
        .show()
        .text reason

    # We have succeeded in retrieving all forms from a FieldDB server.
    # In the FieldDB case we can call `@showLastPage()` because this method
    # is only called once: after all forms have been fetched.
    fetchAllFormsSuccess: ->
      @saveFetchedMetadata()
      @getFormViews()
      @setPaginatorItems()
      @showLastPage()
      @stopSpin()

    # We have succeeded in retrieving a page of forms from an OLD server.
    # `paginator` is an object returned from the OLD. Crucially, it has an
    # attribute `count` which tells us how many forms are in the database.
    # `setPaginatorItems` uses this to sync the client-side pagination GUI
    # with the OLD's server-side pagination.
    fetchOLDFormsSuccess: (paginator) ->
      console.log 'fetch OLD forms successful!'
      @saveFetchedMetadata()
      @getFormViews()
      @setPaginatorItems paginator
      if @paginator.items is 0 then @fetchOLDFormsLastPage = false
      if @fetchOLDFormsLastPage
        console.log 'gonna show last page'
        @fetchOLDFormsLastPage = false
        @showLastPage() # This will fetch the last page and re-call `fetchOLDFormsSuccess`
      else
        console.log 'gonna call refresh page fade'
        @refreshPageFade()

    # Tell the paginator how many items/forms are in our corpus/database.
    setPaginatorItems: (oldPaginator=null) ->
      if oldPaginator
        @paginator.setItems oldPaginator.count # the OLD case
      else
        @paginator.setItems @collection.length # the FieldDB case
      #@paginator.setPageToLast()

    # Remember the server type and name (and corpus name) of the last forms
    # fetch, so we don't needlessly repeat it on future renderings of this
    # entire FormsView. The `@lastFetched` object that is updated here is
    # only accessed by `@weNeedToFetchFormsAgain()` when `@render()` is called.
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

    # Refresh the page to reflect the current state. This means refreshing the
    # top menu header of the forms browse page, the pagination sub-header and
    # the list of forms displayed.
    refreshPage: (options) ->
      @refreshHeader()
      @refreshPaginationMenuTop()
      @closeThenOpenCurrentPage options

    # Refresh the page using fade out/in as the animations.
    refreshPageFade: ->
      @refreshPage
        hideEffect: 'fadeOut'
        showEffect: 'fadeIn'

    # Refresh the content of the forms browse header.
    # This is the top "row" of the header, with the "create a new form"
    # button, the "expand/collapse all" buttons and the title.
    # (Note that the pagination controls are handled by the PaginationMenuTopView.)
    refreshHeader: ->
      if not @fetchCompleted
        @disableHeader()
        return
      if @paginator.items is 0
        @headerForEmptyDataSet()
      else
        @headerForContentfulDataSet()

    # Disable all buttons on the header and tell the user that we're working on
    # fething data from the server.
    disableHeader: ->
      @$('.no-forms')
        .show()
        .text 'Fetching data from the server ...'
      @$('.pagination-info').hide()
      @$('button.expand-all').button 'disable'
      @$('button.collapse-all').button 'disable'
      @$('button.new-form').button 'disable'
      @$('button.toggle-all-labels').button 'disable'

    # Configure the header appropriately for the case where there are no
    # forms to browse.
    headerForEmptyDataSet: ->
      @$('.no-forms')
        .show()
        .text 'There are no forms to display'
      @$('.pagination-info').hide()
      @$('button.expand-all').button 'disable'
      @$('button.collapse-all').button 'disable'
      @$('button.toggle-all-labels').button 'disable'
      @setToggleAllLabelsButtonState()
      @setNewFormViewButtonState()

    # Configure the header appropriately for the case where we have a page
    # that *has* some forms in it.
    headerForContentfulDataSet: ->
      @$('.no-forms').hide()
      @$('.pagination-info').show()
      @$('button.expand-all').button 'enable'
      @$('button.collapse-all').button 'enable'
      @$('button.toggle-all-labels').button 'enable'
      @setToggleAllLabelsButtonState()
      @setNewFormViewButtonState()
      if @paginator.start is @paginator.end
        @$('.form-range')
          .text "form #{@utils.integerWithCommas(@paginator.start + 1)}"
      else
        @$('.form-range').text "forms
          #{@utils.integerWithCommas(@paginator.start + 1)}
          to
          #{@utils.integerWithCommas(@paginator.end + 1)}"
      @$('.form-count').text @utils.integerWithCommas(@paginator.items)
      @$('.form-count-noun').text @utils.pluralizeByNum('form', @paginator.items)
      @$('.current-page').text @utils.integerWithCommas(@paginator.page)
      @$('.page-count').text @utils.integerWithCommas(@paginator.pages)

    # Tell the pagination menu top view to re-render itself given the current
    # state of the paginator.
    refreshPaginationMenuTop: ->
      @paginationMenuTopView.render paginator: @paginator

    # Hide the current page of forms and provide a `complete` callback which
    # will re-open/draw the page with the new forms, by calling `@renderPage`.
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
      100 # Better to be fast than try to do something fancy like below...
      # 100 + (10 * @paginator.itemsDisplayed)

    # Close all rendered form views: remove them from the DOM, but also prevent
    # them from reacting to events.
    closeRenderedFormViews: ->
      while @renderedFormViews.length
        formView = @renderedFormViews.pop()
        formView.close()
        @closed formView

    # Close all rendered pagination item table views, i.e., the mini-tables that
    # hold form views.
    closeRenderedPaginationItemTableViews: ->
      while @renderedPaginationItemTableViews.length
        paginationItemTableView = @renderedPaginationItemTableViews.pop()
        paginationItemTableView.close()
        @closed paginationItemTableView

    # Create a `FormView` instance for each `FormModel` instance in
    # `@collection` and append it to `@formViews`.
    # Note that in the OLD case, we reset `formViews` to `[]` because
    # with server-side pagination we only store one page worth of form
    # models/views at a time.
    # TODO (@cesine @jrwdunham): instantiating a FormView for every FormModel
    # in the collection seems potentially inefficient. Thoughts?
    getFormViews: ->
      if @getActiveServerType() is 'OLD'
        @formViews = []
      @collection.each (formModel) =>
        newFormView = new FormView
          model: formModel
          primaryDataLabelsVisible: @primaryDataLabelsVisible
          expanded: @allFormsExpanded
        @formViews.push newFormView

    spinnerOptions: ->
      _.extend BaseView::spinnerOptions(), {top: '25%', left: '85.5%'}

    spin: -> @$('#dative-page-header').spin @spinnerOptions()

    stopSpin: -> @$('#dative-page-header').spin false

    setFocus: ->
      if @focusedElementIndex?
        @weShouldFocusFirstAddViewInput = false
        @focusLastFocusedElement()
      else if @weShouldFocusFirstAddViewInput
        @focusFirstNewFormViewTextarea()
      else
        @focusLastForm()
      @scrollToFocusedInput()

    focusFirstButton: ->
      @$('button.ui-button').first().focus()

    focusFirstForm: ->
      @$('div.dative-form-object').first().focus()

    focusLastForm: ->
      if @renderedFormViews.length > 0
        @renderedFormViews[@renderedFormViews.length - 1].$el.focus()

    focusFirstNewFormViewTextarea: ->
      @$('.new-form-view .add-form-widget textarea').first().focus()

    # GUI-fy: make nice buttons and nice titles/tooltips
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
      @$('button.toggle-all-labels')
        .button()
        .tooltip
          position:
            my: "left+45 center"
            at: "right center"
            collision: "flipfit"

    perfectScrollbar: ->
      @$('#dative-page-body')
        .perfectScrollbar()
        .scroll => @closeAllTooltips()

    refreshPerfectScrollbar: ->
      @$('#dative-page-body').perfectScrollbar 'update'

    # This was an attempt to refresh perfectScrollbar when the height of the
    # pagin items div changes with the goal of stopping the auto-scroll bug. It
    # was successful in calling `refreshPerfectScrollbar` at the appropriate
    # time, but this did not fix the bug.
    monitorPaginItemsHeight: ->
      @paginItemsHeight = @$('.dative-pagin-items').height()
      paginItemsHeightMonitor = =>
        newHeight = @$('.dative-pagin-items').height()
        if newHeight isnt @paginItemsHeight
          @paginItemsHeight = newHeight
          @refreshPerfectScrollbar()
      @paginItemsHeightMonitorId = setInterval paginItemsHeightMonitor, 1000

    onClose: ->
      clearInterval @paginItemsHeightMonitorId

    # Render a page (pagination) of form views. That is, change which set of
    # `FormView` instances are displayed.
    renderPage: (options) ->
      # @paginator._refresh() # This seems to be unnecessary.
      @renderFormViews()
      @stopSpin()
      @showFormList options

    # Render all form views on the current paginator page.
    # Note the OLD/FieldDB difference: with the OLD, each pagination change
    # event triggers a new fetch to the OLD server, and a resetting of both
    # `@collection` and `@formViews`; thus we render all form models in the
    # collection (and all form views in `@formViews`) using the "indices" from
    # `@paginator`. With FieldDB, we have already fetched *all* forms/datums
    # to `@collection` (and we have all of their respective views in
    # `@formViews`) so we can simply take a slice out of `@formViews` using the
    # paginator start and end values.
    renderFormViews: ->
      paginationIndices = [@paginator.start..@paginator.end]
      if @getActiveServerType() is 'OLD'
        for [index, formView] in _.zip(paginationIndices, @formViews)
          @renderFormView formView, index
      else
        for index in paginationIndices
          formView = @formViews[index]
          @renderFormView formView, index

    # Render a single form view. Embed it in a pagination table view and stick
    # it in the DOM.
    renderFormView: (formView, index) ->
      $formList = @$ '.dative-pagin-items'
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

    # jQuery-show the list of forms.
    showFormList: (options) ->
      $formList = @$ '.dative-pagin-items'
      if options?.showEffect
        $formList[options.showEffect]
          duration: @getAnimationDuration()
          complete: =>
            @setFocus()
      else
        $formList.show()
        @setFocus()


    ############################################################################
    # Respond to requests from the Pagination Menu Top View
    ############################################################################

    changeItemsPerPage: (newItemsPerPage) ->
      Backbone.trigger 'formsView:itemsPerPageChange', newItemsPerPage
      @itemsPerPage = newItemsPerPage
      itemsDisplayedBefore = @paginator.itemsDisplayed
      @paginator.setItemsPerPage newItemsPerPage
      itemsDisplayedAfter = @paginator.itemsDisplayed
      if itemsDisplayedBefore isnt itemsDisplayedAfter
        if @getActiveServerType() is 'FieldDB'
          @refreshPageFade()
        else
          @fetchOLDFormsPageToCollection()

    showFirstPage: ->
      pageBefore = @paginator.page
      @paginator.setPageToFirst()
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        if @getActiveServerType() is 'FieldDB'
          @refreshPageFade()
        else
          @fetchOLDFormsPageToCollection()

    showPreviousPage: ->
      pageBefore = @paginator.page
      @paginator.setPageToPrevious()
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        if @getActiveServerType() is 'FieldDB'
          @refreshPageFade()
        else
          @fetchOLDFormsPageToCollection()

    showNextPage: ->
      pageBefore = @paginator.page
      @paginator.setPageToNext()
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        if @getActiveServerType() is 'FieldDB'
          @refreshPageFade()
        else
          @fetchOLDFormsPageToCollection()

    showLastPage: ->
      pageBefore = @paginator.page
      @paginator.setPageToLast()
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        console.log 'pageBefore isnt pageAfter'
        if @getActiveServerType() is 'FieldDB'
          @refreshPageFade()
        else
          @fetchOLDFormsPageToCollection()
      else
        console.log 'pageBefore IS pageAfter'

    # Show a new page where `method` determines whether the new page is
    # behind or ahead of the current one and where `n` is the number of
    # pages behind or ahead.
    showPage: (n, method) ->
      pageBefore = @paginator.page
      @paginator[method] n
      pageAfter = @paginator.page
      if pageBefore isnt pageAfter
        if @getActiveServerType() is 'FieldDB'
          @refreshPageFade()
        else
          @fetchOLDFormsPageToCollection()

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


    ############################################################################
    # Show, hide and toggle the new form widget view
    ############################################################################

    # Make the new form view visible or not, depending on its last state.
    newFormViewVisibility: ->
      if @newFormViewVisible
        @showNewFormView()
      else
        @hideNewFormView()

    hideNewFormView: ->
      @setNewFormViewButtonShow()
      @newFormViewVisible = false
      @$('.new-form-view').hide()

    showNewFormView: ->
      @setNewFormViewButtonHide()
      @newFormViewVisible = true
      @$('.new-form-view').show
        complete: =>
          @newFormView.showUpdateView()
          Backbone.trigger 'addFormWidgetVisible'

    hideNewFormViewAnimate: ->
      @setNewFormViewButtonShow()
      @newFormViewVisible = false
      @$('.new-form-view').slideUp()
      @newFormView.closeAllTooltips()
      @focusLastForm()
      @scrollToFocusedInput()

    showNewFormViewAnimate: ->
      @setNewFormViewButtonHide()
      @newFormViewVisible = true
      @$('.new-form-view').slideDown
        complete: =>
          @newFormView.showUpdateViewAnimate()
          Backbone.trigger 'addFormWidgetVisible'
      @focusFirstNewFormViewTextarea()
      @scrollToFocusedInput()

    toggleNewFormViewAnimate: ->
      if @$('.new-form-view').is ':visible'
        @hideNewFormViewAnimate()
      else
        @showNewFormViewAnimate()

    setNewFormViewButtonState: ->
      if @newFormViewVisible
        @setNewFormViewButtonHide()
      else
        @setNewFormViewButtonShow()

    setNewFormViewButtonShow: ->
      @$('button.new-form')
        .button 'enable'
        .tooltip
          content: 'create a new form'

    # The form add view show "+" button is disabled when the view is visible; to
    # hide the view, you click on the ^ button on the view itself.
    setNewFormViewButtonHide: ->
      @$('button.new-form')
        .button 'disable'

    showNewFormViewAnimate: ->
      @setNewFormViewButtonHide()
      @newFormViewVisible = true
      @$('.new-form-view').slideDown
        complete: =>
          @newFormView.showUpdateViewAnimate()
          Backbone.trigger 'addFormWidgetVisible'
      @focusFirstNewFormViewTextarea()
      @scrollToFocusedInput()

    # Duplicate the supplied form model, but display a confirm dialog first if the
    # new form view has data in it.
    duplicateFormConfirm: (formModel) ->
      if @newFormView.model.isEmpty()
        @duplicateForm formModel
      else
        id = formModel.get 'id'
        options =
          text: "The “new form” form has unsaved data in it. If you proceed
            with duplicating form #{id}, you will lose that unsaved information.
            Click “Cancel” to abort the duplication so you can save your
            unsaved new form first. If you are okay with discarding your unsaved
            new form, then click “Ok” to proceed with duplicating form #{id}."
          confirm: true
          confirmEvent: 'duplicateForm'
          confirmArgument: formModel
        Backbone.trigger 'openAlertDialog', options

    # Duplicate a form model and display it for editing in the "New Form"
    # widget.
    duplicateForm: (formModel) ->
      newFormModel = formModel.clone()

      # Remove the server-generated attributes of the form. Note: there are
      # other attributes that are server-generated but I'm unsure if these
      # should be removed here (they will be regenerated by the OLD upon save):
      # morpheme_break_ids, morpheme_gloss_ids, break_gloss_category,
      # syntactic_category_string.
      newFormModel.set
        id: null
        UUID: ''
        datetime_entered: ''
        datetime_modified: ''
        enterer: null
        modifier: null
        collections: []

      # TODO: if the current New Form view has a non-empty model we should
      # either warn the user about that or we should intelligently store that
      # model for later ...

      @hideNewFormViewAnimate()
      @closeNewFormView()
      @newFormView = @getNewFormView newFormModel
      @renderNewFormView()
      @listenToNewFormView()
      @showNewFormViewAnimate()

    openExporterDialog: (options) ->
      @exporterDialog.setToBeExported options
      @exporterDialog.generateExport()
      @exporterDialog.dialogOpen()

