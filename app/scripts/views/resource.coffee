define [
  './base'
  './resource-add-widget'
  './field-display'
  './object-with-name-field-display'
  './date-field-display'
  './person-field-display'
  './array-of-objects-with-name-field-display'
  './../utils/globals'
  './../utils/tooltips'
  './../templates/resource'
], (BaseView, ResourceAddWidgetView, FieldDisplayView,
  ObjectWithNameFieldDisplayView, DateFieldDisplayView, PersonFieldDisplayView,
  ArrayOfObjectsWithNameFieldDisplayView, globals, tooltips,
  resourceTemplate) ->

  # Resource View
  # --------------
  #
  # For displaying individual resources.

  class ResourceView extends BaseView

    # Override these in sub-classes.
    resourceName: 'resource'
    resourceAddWidgetView: ResourceAddWidgetView
    primaryAttributes: [] # Attributes that are always displayed.
    secondaryAttributes: [] # Attributes that may be hidden.
    attribute2displayView: {} # Map attribute names to display view class names.

    template: resourceTemplate
    tagName: 'div'
    className: 'dative-resource-widget dative-shadowed-widget
      dative-paginated-item dative-widget-center ui-widget ui-widget-content
      ui-corner-all'

    initialize: (options) ->
      @resourceNameCapitalized = @utils.capitalize @resourceName
      @resourceNamePlural = @utils.pluralize @resourceName
      @resourceNamePluralCapitalized = @utils.capitalize @resourceNamePlural
      @headerTitle = options.headerTitle or ''
      @headerAlwaysVisible = true # the header full of buttons should always be visible.
      @activeServerType = @getActiveServerType()
      @setState options
      @addUpdateType = @getUpdateViewType()
      @updateView = new @resourceAddWidgetView
        model: @model,
        addUpdateType: @addUpdateType
      @updateViewRendered = false

    getUpdateViewType: -> if @model.get('id') then 'update' else 'add'

    # Render the Add a Resource view.
    renderUpdateView: ->
      @updateView.setElement @$('.update-resource-widget').first()
      @updateView.render()
      @updateViewRendered = true
      @rendered @updateView

    # Set the state of the resource display: what is visible.
    setState: (options) ->
      defaults =
        primaryDataLabelsVisible: false # labels for primary data fields
        expanded: false # means that the header of buttons and the secondary data should both be visible
        headerVisible: @headerAlwaysVisible or false # the header full of buttons: is it currently visible?
        headerTitleAttribute: 'name' # the attribute of the model that should be displayed in the header center.
        secondaryDataVisible: false # comments, tags, etc.
        updateViewVisible: false
      _.extend defaults, options
      for key, value of defaults
        @[key] = value
      @effectuateExpanded()

    # `expanded` is a higher-level setting, controlling header and secondary
    # data visibility.
    effectuateExpanded: ->
      if @expanded
        @headerVisible = true
        @secondaryDataVisible = true
      else
        @headerVisible = false
        @secondaryDataVisible = false

    listenToEvents: ->
      super
      @listenTo Backbone,
        "#{@resourceName}:dehighlightAll#{@resourceNameCapitalized}Views",
        @dehighlight
      @listenTo Backbone,
        "#{@resourceNamePlural}View:expandAll#{@resourceNamePluralCapitalized}",
        @expand
      @listenTo Backbone,
        "#{@resourceNamePlural}View:collapseAll#{@resourceNamePluralCapitalized}",
        @collapse
      @listenTo Backbone, "#{@resourceNamePlural}View:showAllLabels",
        @hidePrimaryContentAndLabelsThenShowAll
      @listenTo Backbone, "#{@resourceNamePlural}View:hideAllLabels",
        @hidePrimaryContentAndLabelsThenShowContent
      @listenTo Backbone, "delete#{@resourceNameCapitalized}", @delete
      @listenTo @updateView, "#{@resourceName}AddView:hide",
        @hideUpdateViewAnimate
      @listenTo @model, 'change', @indicateModelState
      @listenTo @updateView, 'forceModelChanged', @indicateModelState
      @listenTo @model, "update#{@resourceNameCapitalized}Success",
        @indicateModelIsUnaltered

    indicateModelState: ->
      if @updateView.modelAltered()
        @indicateModelIsAltered()
      else
        @indicateModelIsUnaltered()

    indicateModelIsAltered: ->
      @$('.dative-widget-header').addClass 'ui-state-error'
      headerTitleHTML = "#{@getHeaderTitle()} (<i class='fa fa-fw
        fa-exclamation-triangle'></i>Unsaved changes)"
      @$('.dative-widget-header-title').first()
        .html headerTitleHTML

    indicateModelIsUnaltered: ->
      @$('.dative-widget-header').removeClass 'ui-state-error'
      @$('.dative-widget-header-title').first().html @getHeaderTitle()

    events:
      'click .resource-primary-data': 'showAndHighlightOnlyMe'
      'mouseenter .resource-primary-data': 'mouseenterPrimaryData'
      'mouseleave .resource-primary-data': 'mouseleavePrimaryData'
      'click .hide-resource-details': 'hideResourceDetails'
      'click .hide-resource-widget': 'hideResourceWidget'
      'click .toggle-secondary-data': 'toggleSecondaryDataAnimate'
      'click .toggle-primary-data-labels': 'togglePrimaryDataLabelsAnimate'
      'focus': 'focus'
      'focusout': 'focusout'
      'keydown': 'keydown'
      'click .update-resource': 'update'
      'click .duplicate-resource': 'duplicate'
      'click .delete-resource': 'deleteConfirm'
      'click .export-resource': 'exportResource'

    exportResource: ->
      Backbone.trigger 'openExporterDialog', model: @model

    update: ->
      @showUpdateViewAnimate()

    duplicate: ->
      Backbone.trigger "duplicate#{@resourceNameCapitalized}Confirm", @model

    # Trigger opening of a confirm dialog: if user clicks "Ok", then this
    # resource will be deleted.
    deleteConfirm: (event) ->
      if event then @stopEvent event
      id = @model.get 'id'
      options =
        text: "Do you really want to delete the #{@resourceName} with id
          “#{id}”?"
        confirm: true
        confirmEvent: "delete#{@resourceNameCapitalized}"
        confirmArgument: id
      Backbone.trigger 'openAlertDialog', options

    # Really delete this resource.
    # This is triggered by the "delete resource" confirm dialog when the user
    # clicks "Ok".
    delete: (resourceId) ->
      if resourceId is @model.get('id')
        @model.destroyResource @model

    render: ->
      @getDisplayViews()
      @html()
      @renderDisplayViews()
      @guify()
      @listenToEvents()
      @renderUpdateView()
      @

    getDisplayViews: ->
      @getPrimaryDisplayViews()
      @getSecondaryDisplayViews()

    # Put the appropriate DisplayView instances in `@primaryDisplayViews`.
    getPrimaryDisplayViews: ->
      @primaryDisplayViews = []
      for attribute in @primaryAttributes
        @primaryDisplayViews.push @getDisplayView attribute

    getSecondaryDisplayViews: ->
      @secondaryDisplayViews = []
      for attribute in @secondaryAttributes
        @secondaryDisplayViews.push @getDisplayView attribute

    # Return the appropriate DisplayView (subclass) instance for a given
    # attribute, as specified in `@attribute2displayView`. The default display
    # view is `FieldDisplayView`.
    getDisplayView: (attribute) ->
      if attribute of @attribute2displayView
        MyDisplayView = @attribute2displayView[attribute]
        new MyDisplayView(@getDisplayViewParams(attribute))
      else # the default display view is FieldDisplayView
        new FieldDisplayView(@getDisplayViewParams(attribute))

    # Return the params for initializing a new `DisplayView` subclass; they all
    # expect `attribute` and `model` on init.
    getDisplayViewParams: (attribute) ->
      resource: @resourceNamePlural
      attribute: attribute # e.g., "name"
      model: @model

    html: ->
      @$el
        .attr 'tabindex', 0
        .html @template(
          activeServerType: @activeServerType
          headerTitle: @getHeaderTitle()
          addUpdateType: @addUpdateType
          headerAlwaysVisible: @headerAlwaysVisible
          resourceName: @resourceName
        )

    getHeaderTitle: ->
      if @headerTitle
        @headerTitle
      else
        @getTruncatedNameAndId()

    # Return a string consisting of the value of the model's `name` attribute
    # truncated to 40 chars, and the model's id. Note: this is probably not
    # general enough a method to be in this base class.
    getTruncatedNameAndId: ->
      name = @model.get 'name'
      id = @model.get 'id'
      if name
        truncatedName = name[0..40]
        if truncatedName isnt name then name = "#{truncatedName}..."
      else
        name = ''
      if id then "#{name} (id #{id})" else name

    # TODO: do this all in one DOM-manipulation event via a single document
    # fragment, if possible.
    renderDisplayViews: ->
      @renderPrimaryDisplayViews()
      @renderSecondaryDisplayViews()

    renderPrimaryDisplayViews: ->
      container = document.createDocumentFragment()
      for displayView in @primaryDisplayViews
        container.appendChild displayView.render().el
        @rendered displayView
      @$('div.resource-primary-data').append container

    renderSecondaryDisplayViews: ->
      container = document.createDocumentFragment()
      for displayView in @secondaryDisplayViews
        container.appendChild displayView.render().el
        @rendered displayView
      @$('div.resource-secondary-data').append container

    guify: ->
      @primaryDataLabelsVisibility()
      @guifyButtons()
      @headerVisibility()
      @secondaryDataVisibility()
      @updateViewVisibility()

    # Make the header visible, or not, depending on state.
    headerVisibility: ->
      if @headerAlwaysVisible then @addBorder()
      if @headerVisible
        @showHeader()
        @turnOffPrimaryDataTooltip()
      else
        @hideHeader()
        @turnOnPrimaryDataTooltip()

    # Make the secondary data visible, or not, depending on state.
    secondaryDataVisibility: ->
      if @secondaryDataVisible
        @showSecondaryData()
      else
        @hideSecondaryData()

    # Make the update view visible, or not, depending on state.
    updateViewVisibility: ->
      if @updateViewVisible
        @showUpdateView()
      else
        @hideUpdateView()

    # Hide/show the labels for the primary data.
    togglePrimaryDataLabelsAnimate: ->
      if @primaryDataLabelsVisible
        @hidePrimaryContentAndLabelsThenShowContent()
      else
        @hidePrimaryContentAndLabelsThenShowAll()

    # Fade out primary data, then fade in primary data and labels.
    hidePrimaryContentAndLabelsThenShowAll: ->
      @$(@primaryDataContentSelector).fadeOut
        complete: =>
          @showPrimaryDataLabelsAnimate()
          @showPrimaryDataContentAnimate()
          @$(@primaryDataContentSelector).removeClass 'no-label'

    # Fade out primary data and labels, then fade in primary data.
    hidePrimaryContentAndLabelsThenShowContent: ->
      @hidePrimaryDataLabelsAnimate()
      @$(@primaryDataContentSelector).fadeOut
        complete: =>
          @showPrimaryDataContentAnimate()
          @$(@primaryDataContentSelector).addClass 'no-label'

    # Fade in primary data content.
    showPrimaryDataContentAnimate: ->
      @$(@primaryDataContentSelector).fadeIn()

    # "Show labels" button.
    setPrimaryDataLabelsButtonStateClosed: ->
      @$('.toggle-primary-data-labels')
        .find 'i.fa'
          .removeClass 'fa-toggle-on'
          .addClass 'fa-toggle-off'
          .end()
        .button()
        .tooltip
          items: 'button'
          content: 'show labels'

    # "Hide labels" button.
    setPrimaryDataLabelsButtonStateOpen: ->
      @$('.toggle-primary-data-labels')
        .find 'i.fa'
          .removeClass 'fa-toggle-off'
          .addClass 'fa-toggle-on'
          .end()
        .button()
        .tooltip
          items: 'button'
          content: 'hide labels'

    primaryDataLabelsSelector: '.dative-field-display-label-container'

    primaryDataContentSelector: '.dative-field-display-representation-container'

    # Show the labels for the primary data attributes.
    showPrimaryDataLabelsAnimate: ->
      @primaryDataLabelsVisible = true
      @setPrimaryDataLabelsButtonStateOpen()
      @$(@primaryDataLabelsSelector).fadeIn().css('display', 'inline-block')

    # Hide the labels for the primary data attributes.
    hidePrimaryDataLabelsAnimate: (event) ->
      @primaryDataLabelsVisible = false
      @setPrimaryDataLabelsButtonStateClosed()
      @$(@primaryDataLabelsSelector).fadeOut()

    # Make the primary data visible, or not, depending on state.
    primaryDataLabelsVisibility: ->
      if @primaryDataLabelsVisible
        @showPrimaryDataLabels()
      else
        @hidePrimaryDataLabels()

    # Toggle the visibility of the primary data labels.
    togglePrimaryDataLabels: ->
      if @primaryDataLabelsVisible
        @hidePrimaryDataLabels()
      else
        @showPrimaryDataLabels()

    hidePrimaryDataLabels: ->
      @primaryDataLabelsVisible = false
      @setPrimaryDataLabelsButtonStateClosed()
      @$(@primaryDataLabelsSelector).hide()
      @$(@primaryDataContentSelector).addClass 'no-label'

    showPrimaryDataLabels: ->
      @primaryDataLabelsVisible = true
      @setPrimaryDataLabelsButtonStateOpen()
      @$(@primaryDataLabelsSelector).show().css 'display', 'inline-block'
      @$(@primaryDataContentSelector).removeClass 'no-label'

    # jQueryUI-ify <button>s
    guifyButtons: ->

      @$('button.hide-resource-details, button.hide-resource-widget')
        .button()
        .tooltip
          items: 'button'
          position:
            my: "right-10 center"
            at: "left center"
            collision: "flipfit"

      @$('button.toggle-secondary-data')
        .button()
        .tooltip
          position:
            my: "right-45 center"
            at: "left center"
            collision: "flipfit"

      @$('button.toggle-primary-data-labels')
        .button()
        .tooltip
          position:
            my: "right-80 center"
            at: "left center"
            collision: "flipfit"

      # Make all of righthand-side buttons into jQuery buttons and set the
      # position of their tooltips programmatically.
      @$(@$('.button-container-right button').get().reverse())
        .each (index, element) =>
          leftOffset = (index * 35) + 10
          @$(element)
            .button()
            .tooltip
              position:
                my: "left+#{leftOffset} center"
                at: "right center"
                collision: "flipfit"

    # Button for toggling secondary data: when secondary data are hidden.
    setSecondaryDataButtonStateClosed: ->
      @$('.toggle-secondary-data')
        .find('i')
          .removeClass('fa-angle-up')
          .addClass('fa-angle-down')
          .end()
        .button()
        .tooltip
          items: 'button'
          content: "show the secondary data of this #{@resourceName}"

    # Button for toggling secondary data: when secondary data are visible.
    setSecondaryDataButtonStateOpen: ->
      @$('.toggle-secondary-data')
        .find('i')
          .removeClass('fa-angle-down')
          .addClass('fa-angle-up')
          .end()
        .button()
        .tooltip
          items: 'button'
          content: "hide the secondary data of this #{@resourceName}"

    setUpdateButtonStateOpen: -> @$('.update-resource').button 'disable'

    setUpdateButtonStateClosed: -> @$('.update-resource').button 'enable'

    # Expand the resource view: show buttons and secondary data.
    expand: ->
      # ResourcesView listens for this once in order to scroll to the correct
      # place.
      @showSecondaryDataEvent = "#{@resourceName}:#{@resourceName}Expanded"
      @showFullAnimate()

    # Collapse the resource view: hide buttons and secondary data.
    collapse: ->
      # ResourcesView listens for this once in order to scroll to the correct
      # place.
      @hideSecondaryDataEvent = "#{@resourceName}:#{@resourceName}Collapsed"
      @hideFullAnimate()

    # Highlight the resource view and show its secondary data.
    highlightAndShow: ->
      @highlight()
      @showSecondaryData()

    # Highlight self, show self's extra data, tell other resource views to dehighlight themselves.
    showAndHighlightOnlyMe: ->
      if not @headerVisible
        @showFullAnimate()
        @highlightOnlyMe()

    highlight: ->
      @$el.addClass 'ui-state-highlight'

    highlightOnlyMe: ->
      @dehighlightAll()
      @highlight()

    dehighlightAll: ->
      Backbone.trigger(
        "#{@resourceName}:dehighlightAll#{@resourceNameCapitalized}Views")

    dehighlight: ->
      @$el.removeClass 'ui-state-highlight'

    dehighlightAndHide: ->
      @dehighlight()
      @hideSecondaryData()

    focus: ->
      @highlightOnlyMe()

    focusout: ->
      @dehighlight()

    # <Enter> on a closed resource opens it, <Esc> on an open resource closes
    # it.
    keydown: (event) ->
      switch event.which
        when 27
          if @addUpdateType is 'add'
            @hideResourceWidget()
          else if @headerVisible
            @hideResourceDetails()
        when 13 # Enter expands: note if the focused element lacks class, that's because the entire widget is focused.
          if not @headerVisible or not @$(':focus').attr('class')
            @showFullAnimate()
        when 85 # "u" for "update"
          if not @addUpdateResourceWidgetHasFocus()
            @$('.update-resource').first().click()
        when 68 # "d" for "delete"
          if not @addUpdateResourceWidgetHasFocus()
            @$('.delete-resource').first().click()
        when 69 # "e" for "export"
          if not @addUpdateResourceWidgetHasFocus()
            @$('.export-resource').first().click()

    ############################################################################
    # Hide & Show stuff
    ############################################################################

    # Hide details and self-focus. Clicking on the double-angle-up
    # (hide-resource-details) button calls this, as does `@keydown` with <Esc>.
    hideResourceDetails: ->
      @hideFullAnimate()
      @$el.focus()

    # Hide details and then completely hide self. Clicking on the X
    # (hide-resource-widget) button calls this, as does `@keydown` with <Esc>.
    hideResourceWidget: ->
      @trigger "new#{@resourceNameCapitalized}View:hide"

    # Full = border, header & secondary data
    ############################################################################

    showFull: ->
      @addBorder()
      @turnOffPrimaryDataTooltip()
      @showHeader()
      @showSecondaryData()

    hideFull: ->
      @removeBorder()
      @turnOnPrimaryDataTooltip()
      @hideHeader()
      @hideSecondaryData()

    showFullAnimate: ->
      @addBorderAnimate()
      @turnOffPrimaryDataTooltip()
      @showHeaderAnimate()
      @showSecondaryDataAnimate()

    hideFullAnimate: ->
      @removeBorderAnimate()
      @turnOnPrimaryDataTooltip()
      @hideHeaderAnimate()
      @hideSecondaryDataAnimate()
      @hideUpdateViewAnimate()

    # Header
    ############################################################################

    showHeader: ->
      @headerVisible = true
      @$('.dative-widget-header').first().show()

    hideHeader: ->
      if not @headerAlwaysVisible
        @headerVisible = false
        @$('.dative-widget-header').first().hide()

    showHeaderAnimate: ->
      @headerVisible = true
      @$('.dative-widget-header').first().slideDown()

    hideHeaderAnimate: ->
      if not @headerAlwaysVisible
        @headerVisible = false
        @$('.dative-widget-header').first().slideUp()

    # Secondary Data
    ############################################################################

    showSecondaryData: ->
      @secondaryDataVisible = true
      @setSecondaryDataButtonStateOpen()
      @addBorder()
      @$('.resource-secondary-data').show()

    hideSecondaryData: ->
      @secondaryDataVisible = false
      @setSecondaryDataButtonStateClosed()
      @removeBorder()
      @$('.resource-secondary-data').hide()

    toggleSecondaryData: ->
      if @secondaryDataVisible
        @hideSecondaryData()
      else
        @showSecondaryData()

    showSecondaryDataAnimate: ->
      @secondaryDataVisible = true
      @setSecondaryDataButtonStateOpen()
      @addBorderAnimate()
      @$('.resource-secondary-data').slideDown
        complete: =>
          # ResourcesView listens once for this and fixes scroll position and focus in response
          if @showSecondaryDataEvent
            Backbone.trigger @showSecondaryDataEvent
            @showSecondaryDataEvent = null

    hideSecondaryDataAnimate: (event) ->
      @secondaryDataVisible = false
      @setSecondaryDataButtonStateClosed()
      @$('.resource-secondary-data').slideUp
        complete: =>
          # ResourcesView listens once for this and fixes scroll position and focus in response
          if @hideSecondaryDataEvent
            Backbone.trigger @hideSecondaryDataEvent
            @hideSecondaryDataEvent = null

    toggleSecondaryDataAnimate: ->
      if @secondaryDataVisible
        @hideSecondaryDataAnimate()
      else
        @showSecondaryDataAnimate()


    # Update View
    ############################################################################

    showUpdateView: ->
      if not @updateViewRendered then @renderUpdateView()
      @updateViewVisible = true
      @setUpdateButtonStateOpen()
      @$('.update-resource-widget').show
        complete: =>
          @showFull()
          Backbone.trigger "add#{@resourceNameCapitalized}WidgetVisible"
          @focusFirstUpdateViewTextarea()

    hideUpdateView: ->
      @updateViewVisible = false
      @setUpdateButtonStateClosed()
      @$('.update-resource-widget').hide()

    toggleUpdateView: ->
      if @updateViewVisible
        @hideUpdateView()
      else
        @showUpdateView()

    showUpdateViewAnimate: ->
      if not @updateViewRendered then @renderUpdateView()
      @updateViewVisible = true
      @setUpdateButtonStateOpen()
      @$('.update-resource-widget').slideDown
        complete: =>
          @showFullAnimate()
          Backbone.trigger "add#{@resourceNameCapitalized}WidgetVisible"
          @focusFirstUpdateViewTextarea()

    focusFirstUpdateViewTextarea: ->
      @$('.update-resource-widget textarea').first().focus()

    hideUpdateViewAnimate: ->
      @updateViewVisible = false
      @setUpdateButtonStateClosed()
      @$('.update-resource-widget').slideUp
        complete: => @$el.focus()

    toggleUpdateViewAnimate: ->
      if @updateViewVisible
        @hideUpdateViewAnimate()
      else
        @showUpdateViewAnimate()


    # Border
    ############################################################################

    addBorder: ->
      @$el
        .css 'border-color': @constructor.jQueryUIColors().defBo
        .addClass 'expanded'

    removeBorder: ->
      if not @headerAlwaysVisible
        @$el
          .css 'border-color': 'transparent'
          .removeClass 'expanded'

    addBorderAnimate: ->
      @$el
        .animate 'border-color': @constructor.jQueryUIColors().defBo
        .addClass 'expanded'

    removeBorderAnimate: ->
      if not @headerAlwaysVisible
        @$el
          .animate 'border-color': 'transparent'
          .removeClass 'expanded'


    # Primary Data
    ############################################################################

    mouseenterPrimaryData: ->
      if not @headerVisible
        @$('.resource-primary-data').css 'cursor', 'pointer'
      else
        @$('.resource-primary-data').css 'cursor', 'text'

    mouseleavePrimaryData: ->
      if not @headerVisible
        @$('.resource-primary-data').css 'cursor', 'text'

    # The resource display representations in the primary data section have
    # tooltips only when the buttons and secondary data are hidden.
    turnOnPrimaryDataTooltip: ->
      @$('.dative-field-display-representation-container').each (index, element) =>
        $element = @$ element
        if not $element.tooltip 'instance'
          $element
            .tooltip
              open: (event, ui) -> ui.tooltip.css "max-width", "200px"
              items: 'div'
              content: 'Click here for controls and more data.'
              position:
                my: 'right-10 center'
                at: 'left center'
                collision: 'flipfit'

    turnOffPrimaryDataTooltip: ->
      @$('.dative-field-display-representation-container').each (index, element) =>
        $element = @$ element
        if $element.tooltip 'instance' then $element.tooltip 'destroy'

    getActiveServerType: ->
      globals.applicationSettings.get('activeServer').get 'type'


    ############################################################################
    # General template helpers
    ############################################################################

    styleDisplayNone: ' style="display: none;" '

    # Return an in-line CSS style to hide the HTML of an empty resource attribute
    # Note the use of `=>` so that the ECO template knows to use this view's
    # context.
    displayNoneStyle: (value) =>
      if _.isDate(value) or _.isNumber(value)
        ''
      else if _.isEmpty(value) or @isValueless(value)
        @styleDisplayNone
      else
        ''

    # Returns `true` only if thing is an object all of whose values are either
    # `null` or empty strings.
    isValueless: (thing) ->
      _.isObject(thing) and
      (not _.isArray(thing)) and
      _.isEmpty(_.filter(_.values(thing), (x) -> x isnt null and x isnt ''))

