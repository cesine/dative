define [
  'backbone'
  './base'
  './server'
  './../models/server'
  './../templates/servers'
], (Backbone, BaseView, ServerView, ServerModel, serversTemplate) ->

  # Servers View
  # -------------
  #
  # A view for a collection of server objects.

  class ServersView extends BaseView

    tagName: 'div'
    template: serversTemplate

    # Return `true` if you want the triangle button for toggling the servers
    # view.
    hideable: -> false

    initialize: (options) ->
      @serverTypes = options.serverTypes
      @serverViews = []
      @collection.each (server) =>
        newServerView = new ServerView
          model: server
          serverTypes: @serverTypes
        @serverViews.push newServerView
      @bodyVisible = options.bodyVisible or false

    listenToEvents: ->
      @listenTo Backbone, 'removeServerView', @removeServerView
      @delegateEvents()

    removeServerView: (serverView) ->
      @serverViews = _.without @serverViews, serverView
      serverView.close()
      @closed serverView
      @emptyMessage()
      @$('button.toggle-appear').first().focus()

    emptyMessage: ->
      if @serverViews.length is 0
        @$('div.no-servers-msg').show()
      else
        @$('div.no-servers-msg').hide()

    events:
      'keydown button.toggle-appear': 'toggleServerConfigKeys'
      'keydown button.add-server': 'addServerKeys'
      'click button.toggle-appear': 'toggleServerConfig'
      'click button.add-server': 'addServer'
      'click button.servers-help': 'serversHelp'

    # Tell the Help dialog to open itself and search for "servers"
    # and scroll to the Xth match. WARN: this is brittle because if the help
    # HTML changes, then the Xth match may not be what we want....
    serversHelp: ->
      Backbone.trigger(
        'helpDialog:openTo',
        searchTerm: "servers"
        scrollToIndex: 1
      )

    render: ->
      @$el.html @template(hideable: @hideable())
      @guify()
      @$widgetBody = @$('div.dative-widget-body').first()
      container = document.createDocumentFragment()
      for serverView in @serverViews
        container.appendChild serverView.render().el
        @rendered serverView
      @$widgetBody.append container
      if @bodyVisible then @showServerConfig() else @hideServerConfig()
      @emptyMessage()
      @listenToEvents()
      @

    setCollectionFromGUI: ->
      updatedServerModels = []
      for serverView in @serverViews
        serverView.setModelFromGUI()
        updatedServerModels.push serverView.model
      @collection.add updatedServerModels

    addServer: (event) ->
      if event
        event.preventDefault()
        event.stopPropagation()
      @openServerConfig()
      serverModel = new ServerModel()
      @collection.unshift serverModel
      serverView = new ServerView
        model: serverModel
        serverTypes: @serverTypes
      @serverViews.unshift serverView
      serverView.render().$el.prependTo(@$widgetBody).hide().slideDown('slow')
      @rendered serverView
      @emptyMessage()

    guify: ->

      @$('button').button().attr('tabindex', 0)

      @$('button.servers-help')
        .tooltip position: @tooltipPositionRight()

      @$('button.toggle-appear')
        .tooltip
          position:
            my: "right-20 center"
            at: "left center"
            collision: "flipfit"

      @$('button.add-server')
        .tooltip
          position:
            my: "right-50 center"
            at: "left center"
            collision: "flipfit"

    toggleServerConfig: (event) ->
      if event then @stopEvent event
      $body = @$('.dative-widget-body').first()
      if $body.is ':visible'
        @closeServerConfig()
      else
        @openServerConfig()

    closeServerConfig: ->
      @setBodyStateClosed()
      $body = @$('.dative-widget-body').first()
      if $body.is ':visible' then $body.slideUp()

    hideServerConfig: ->
      @setBodyStateClosed()
      @$('.dative-widget-body').first().hide()

    showServerConfig: ->
      @setBodyStateOpen()
      @$('.dative-widget-body').first().show()

    openServerConfig: ->
      @setBodyStateOpen()
      $body = @$('.dative-widget-body').first()
      if not $body.is ':visible' then $body.slideDown()
      # $firstInput = @$('input[name=name]').first()
      # $firstInput.focus()

    setBodyStateClosed: ->
      @bodyVisible = false
      @setHeaderStateClosed()
      @setToggleButtonStateClosed()

    setBodyStateOpen: ->
      @bodyVisible = true
      @setHeaderStateOpen()
      @setToggleButtonStateOpen()

    setToggleButtonStateClosed: ->
      @$('button.toggle-appear')
        .find('i').removeClass('fa-caret-down').addClass('fa-caret-right').end()
        .button()
        .tooltip content: 'show servers'

    setToggleButtonStateOpen: ->
      @$('button.toggle-appear')
        .find('i').addClass('fa-caret-down').removeClass('fa-caret-right').end()
        .button()
        .tooltip content: 'hide servers'

    rememberTarget: (event) ->
      try
        @$('.dative-input-display').each (index, el) =>
          if el is event.target
            @focusedElementIndex = index

    toggleServerConfigKeys: (event) ->
      @rememberTarget event
      if event.which in [13, 37, 38, 39, 40] then @stopEvent event
      switch event.which
        when 13 # Enter
          @toggleServerConfig()
        when 37, 38 # left and up arrows
          @closeServerConfig()
        when 39, 40 # right and down arrows
          @openServerConfig()

    addServerKeys: (event) ->
      @rememberTarget event
      if event.which is 13 # Enter
        @stopEvent event
        @addServer()

