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

    listenToEvents: ->
      @listenTo @model.get('servers'), 'add', @newServerAdded
      @listenTo @model.get('servers'), 'remove', @serverRemoved
      @listenTo @model.get('servers'), 'change', @serverChanged

    render: ->
      context =
        activeServerId: @model.get('activeServer')?.get('id')
        servers: @model.get('servers').toJSON()
      @$el.html @template(context)
      @$('select.activeServer').selectmenu()
      @listenToEvents()
      @

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
      selectedValue = @$('select[name=activeServer]').val()
      if selectedValue is 'null' then selectedValue is null
      @model.set 'activeServer', selectedValue

