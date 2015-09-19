define [
  './base'
  './../utils/globals'
  './../templates/button-control'
], (BaseView, globals, buttonControlTemplate) ->

  # Serve Compiled Control View
  # ---------------------------
  #
  # View for a control for requesting that an FST-based resource return its
  # compiled file representation.

  class ServeCompiledControlView extends BaseView

    template: buttonControlTemplate
    className: 'serve-compiled-control-view control-view dative-widget-center'

    initialize: (options) ->
      @activeServerType = @getActiveServerType()
      @listenToEvents()
      @resourceName = options.resourceName or 'phonology'

    events:
      'click button.serve-compiled':         'serveCompiled'

    listenToEvents: ->
      super
      @listenTo @model, "serveCompiledStart", @serveCompiledStart
      @listenTo @model, "serveCompiledEnd", @serveCompiledEnd
      @listenTo @model, "serveCompiledFail", @serveCompiledFail
      @listenTo @model, "serveCompiledSuccess", @serveCompiledSuccess
      @listenTo @model, "change:compile_succeeded", @serveCompiledButtonAbility

    controlResultsClass: 'serve-compiled-results'
    conrolSummaryClass: 'serve-compiled-summary'

    # Write the initial HTML to the page.
    html: ->
      context =
        buttonClass: 'serve-compiled'
        buttonTitle: "Clicking this button will cause the binary file that
          represents the compiled #{@resourceName} to be downloaded from the
          server."
        buttonText: 'Serve Compiled'
        controlResultsClass: @controlResultsClass
        conrolSummaryClass: @conrolSummaryClass
      @$el.html @template(context)

    render: ->
      @html()
      @guify()
      @listenToEvents()
      @serveCompiledButtonAbility()
      @

    guify: ->
      @buttonify()
      @tooltipify()

    tooltipify: ->
      @$('.dative-tooltip')
        .tooltip position: @tooltipPositionLeft('-20')

    spinnerOptions: (top='50%', left='-170%') ->
      options = super
      options.top = top
      options.left = left
      options.color = @constructor.jQueryUIColors().defCo
      options

    spin: (selector='.spinner-container', top='50%', left='-170%') ->
      @$(selector).spin @spinnerOptions(top, left)

    stopSpin: (selector='.spinner-container') ->
      @$(selector).spin false

    ############################################################################
    # Serve Compiled
    ############################################################################

    serveCompiled: ->
      @model.serveCompiled()

    serveCompiledStart: ->
      @spin 'button.serve-compiled', '50%', '135%'
      @$(".#{@conrolSummaryClass}").html ''
      @disableServeCompiledButton()

    serveCompiledEnd: ->
      @stopSpin 'button.serve-compiled'
      @enableServeCompiledButton()

    serveCompiledFail: (error) ->
      Backbone.trigger "#{@resourceName}ServeCompiledFail", error, @model.get('id')

    serveCompiledSuccess: (binaryFomaFile) ->
      Backbone.trigger "#{@resourceName}ServeCompiledSuccess", @model.get('id')
      @displayLinkToFomaFile binaryFomaFile

    displayLinkToFomaFile: (binaryFomaFile) ->
      blob = new Blob([binaryFomaFile], {type: 'application/octet-stream'})
      url = URL.createObjectURL(blob)
      filename =
        "#{@resourceName}-#{@model.get('id')}-#{(new Date()).getTime()}.foma"
      title = "Click here to download this compiled #{@resourceName} file; the
        “foma” program can read this file."
      $anchor = $('<a>')
        .attr
          href: url
          download: filename
          title: title
          class: 'serve-compiled-anchor'
        .html "#{filename}<i class='fa fa-fw fa-download'></i>"
        .tooltip()
      @$(".#{@controlResultsClass}").html $anchor
      @$(".#{@conrolSummaryClass}").html 'DAVe'

    disableServeCompiledButton: ->
      @$('button.serve-compiled').button 'disable'

    enableServeCompiledButton: ->
      @$('button.serve-compiled').button 'enable'

    serveCompiledButtonAbility: ->
      if @model.get('compile_succeeded') is false
        @disableServeCompiledButton()
      else
        @enableServeCompiledButton()

