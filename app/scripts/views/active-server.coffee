define [
  'backbone'
  './base'
  './../templates/active-server'
], (Backbone, BaseView, activeServerTemplate) ->

  # Active Server View
  # ------------------
  #
  # Purpose: the "Active Server" select reflects the state of the servers
  # collection.
  #
  # A view dedicated to a single jQueryUI selectmenu which indicates the active
  # server. The model is the entire `applicationSettings` instance initialized
  # in `app.coffee`.

  class ActiveServerView extends BaseView

    template: activeServerTemplate

    initialize: (options) ->
      @width = options.width or 540
      @label = options.label or 'Active Server'
      @tooltipPosition = options.tooltipPosition or {
        my: "left top+15", at: "left bottom", collision: "flipfit"}
      @tooltipContent = options.tooltipContent or 'select the active server'

    events:
      'selectmenuchange': 'setModelFromGUI'

    listenToEvents: ->
      @listenTo @model.get('servers'), 'add', @newServerAdded
      @listenTo @model.get('servers'), 'remove', @serverRemoved
      @listenTo @model.get('servers'), 'change', @serverChanged
      @listenTo @model, 'change:loggedIn', @loggedInChanged
      @listenTo @model, 'change:activeServer', @activeServerChanged
      @delegateEvents()

    loggedInChanged: ->
      @selectmenuify()

    loggedIn: ->
      @model.get 'loggedIn'

    selectmenuify: ->
      disabled = if @loggedIn() then true else false
      @$('select.activeServer')
        .selectmenu
          width: @width
          disabled: disabled

    render: ->
      context =
        label: @label
        activeServerId: @model.get('activeServer')?.get?('id')
        servers: @model.get('servers').toJSON()
      @$el.html @template(context)
      @selectmenuify()
      @$('.ui-selectmenu-button')
        .addClass 'dative-tooltip dative-select-active-server'
        .tooltip
          items: 'span'
          content: @tooltipContent
          position: @tooltipPosition
      @listenToEvents()
      @

    activeServerChanged: ->
      activeServer = @model.get 'activeServer'
      if activeServer
        @$('select.activeServer').val activeServer.get('id')
      else
        @$('select.activeServer').val 'null'
      @$('select.activeServer').selectmenu 'refresh'

    serverChanged: (serverModel) ->
      @$('select.activeServer')
        .find("option[value=#{serverModel.get('id')}]")
          .text(serverModel.get('name')).end()
        .selectmenu('refresh')

    newServerAdded: (newServerModel) ->
      newOptionElement = $('<option/>',
        value: newServerModel.get('id')
        text: newServerModel.get('name'))
      @$('select.activeServer option[value=null]').after(newOptionElement)

    serverRemoved: (serverModel) ->
      @$('select.activeServer')
        .find("option[value=#{serverModel.get('id')}]").remove().end()
        .selectmenu('refresh')

    setModelFromGUI: ->
      selectedServerId = @$('select[name=activeServer]').val()
      if selectedServerId is 'null' then selectedServerId is null
      activeServer = @model.get('servers').get selectedServerId
      @model.set 'activeServer', activeServer

    disable: ->
      @$('select.activeServer').selectmenu 'disable'

    enable: ->
      @$('select.activeServer').selectmenu 'enable'

