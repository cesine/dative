define [
  'backbone'
  './form-handler-base'
  './label'
  './textarea-input'
  './../utils/globals'
  './../utils/tooltips'
  './../templates/field'
], (Backbone, FormHandlerBaseView, LabelView, TextareaInputView, globals,
  tooltips, fieldTemplate) ->

  # Field View
  # ----------
  #
  # A base class view for data input fields for a single attribute of a model:
  # basically a label and one or more input controls (and possible some
  # validation machinery). NOTE: assumes that the `@model` is a form model.
  #
  # Example usage:
  #
  #   syntaxFieldView = new FieldView
  #     attribute: 'syntacticTreeLatex'
  #     model: @myFormModelInstance
  #
  # The DOM real estate controlled by this type of view is typically an <li>
  # with a <label> and one or more inputs (e.g., <input type="text">, <select>
  # or <textarea>) that is used to modify/create a value for a single form
  # attribute, e.g., `transcription`, `utterance`, `translations`, etc.
  #
  # The default behaviour is to display a `LabelView` instance and a
  # `TextareaInputView` instance.
  #
  # The object passed to the constructor of a `FieldView` instance (or subclass
  # thereof) must minimally have an `attribute` key. The HTML attribute values
  # (class, value, title, name, etc.) are all generated from this `attribute`
  # value (given certain assumptions about the data structure and notational
  # conventions of FieldDB and OLD datums/forms.
  #
  # While any method may be overridden in sub-classes, typical sub-classing will
  # involve overriding `getInputView`. The helper methods used to generate the
  # context object for templates constitute the bulk of the re-usable code
  # here. See `getName`, `getValue`, `getTooltip`, etc. below.

  class FieldView extends FormHandlerBaseView

    # Override this in a subclass to swap in a new input view, e.g., one based
    # on a <select> or an <input[type=text]>, or even an "input set" view (see
    # `InputSetView`.)
    getInputView: ->
      new TextareaInputView @context

    # Override this in a subclass to swap in a new label view.
    getLabelView: ->
      new LabelView @context

    # Override this in a subclass to provide non-standard contextual attributes.
    # Input views expect a context object to be passed to their constructors,
    # which they will in turn pass to their templates.
    getContext: ->
      attribute: @attribute
      options: @options
      model: @model
      name: @getName()
      class: @getClass()
      title: @getTooltip()
      value: @getValue()
      label: @getLabel()
      domAttributes: @domAttributes
      fieldLabelContainerClass: @getFieldLabelContainerClass()
      fieldInputContainerClass: @getFieldInputContainerClass()

    getFieldInputContainerClass: ->
      'dative-field-input-container'

    getFieldLabelContainerClass: ->
      'dative-field-label-container'

    guify: ->

    showLabel: true

    template: fieldTemplate
    tagName: 'li'
    className: 'dative-form-field'

    initialize: (options) ->
      @addUpdateType = options.addUpdateType or 'add'
      @tooltipIsRefreshable = options.tooltipIsRefreshable or false
      @resource = options.resource or 'forms'
      @submitAttempted = false
      @attribute = options.attribute
      @domAttributes = options.domAttributes or {}
      @activeServerType = @getActiveServerType()
      @options = options.options # possible values for forced-choice fields, e.g., `users` or `grammaticalities` with an OLD back-end.
      @context = @getContext()
      @labelView = @getLabelView()
      @inputView = @getInputView()

    # Default is to call `set` on the model any time a field input changes.
    events:
      'change':                'setToModel' # fires when multi-select changes
      'input':                 'setToModel' # fires when an input, textarea or date-picker changes
      'selectmenuchange':      'setToModel' # fires when a selectmenu changes
      'menuselect':            'setToModel' # fires when the tags multi-select changes (not working?...)
      'keydown .ms-container': 'multiselectKeydown'
      'keydown textarea, input, .ui-selectmenu-button, .ms-container':
                               'controlEnterSubmit'

    render: ->
      @$el.html @template(@context)
      @$('.dative-field-validation-container').hide()
      if @showLabel then @renderLabelView()
      @renderInputView()
      @guify()
      @listenToEvents()
      if not @visibilityCondition() then @$el.hide()
      @

    # Make this method evaluate to false under those conditions when this view
    # should be hidden.
    visibilityCondition: -> true

    # Refresh re-renders all of the input views. This is called by the form add
    # widget when the “clear form” button is clicked.
    refresh: (model) ->
      if model then @model = model
      @context = @getContext()
      if @inputView
        @inputView.refresh @context

    listenToEvents: ->
      super
      if @inputView
        @listenTo @inputView, 'setToModel', @inputViewSetToModel
      @listenForValidationErrors()
      for crucialAttribute in @getCrucialAttributes()
        @listenTo @model, "change:#{crucialAttribute}", @crucialAttributeChanged

    # Override this to return an array of model attributes. This will cause this
    # field view's visibility to vary depending on characteristics of the
    # values of those attributes.
    getCrucialAttributes: -> []

    crucialAttributeChanged: ->
      if @visibilityCondition() then @showAnimate() else @hideAnimate()

    hideAnimate: -> if @$el.is ':visible' then @$el.slideUp()

    showAnimate: -> if not @$el.is(':visible') then @$el.slideDown()

    # We listen to validation error events that are relevant to our
    # attribute(s). Note: this may need to be over-ridden in sub-classes.
    listenForValidationErrors: ->
      @listenTo @context.model, "validationError:#{@attribute}",
        @validationError

    renderLabelView: ->
      @labelView.setElement @$('.dative-field-label-container')
      @labelView.render()
      @rendered @labelView

    renderInputView: ->
      @inputView.setElement @$('.dative-field-input-container')
      @inputView.render()
      @rendered @inputView

    # CTRL+ENTER in an input-type element should trigger form submission.
    controlEnterSubmit: (event) ->
      if event.ctrlKey and event.which is 13
        @stopEvent event
        @trigger 'submit'

    # multiSelect doesn't let you SHIFT+TAB up/out. This fixes that.
    # `FormAddWidgetView` listens for the event.
    multiselectKeydown: (event) ->
      if event.shiftKey and event.which is 9
        @stopEvent event
        @trigger 'focusPreviousField'

    ############################################################################
    # Getting the field values from the DOM and setting them to the Backbone
    # model.
    ############################################################################

    # Return the value of the attribute represented by this field, given the
    # data in the DOM's input fields. Returns an object where keys are FieldDB
    # datum(Field) labels/attributes or OLD form attributes. E.g., `{utterance:
    # "chienon", judgement: "*"}`
    getValueFromDOM: ->
      @inputView.getValueFromDOM()

    # Set the state of this field to the model.
    setToModel: ->
      domValue = @getValueFromDOM()
      switch @activeServerType
        when 'FieldDB' then @model.setDatumValueSmart domValue
        when 'OLD' then @model.set domValue
      if @submitAttempted then @validate()

    inputViewSetToModel: -> @setToModel()

    validate: (errors) ->
      clientSideValidationErrors = errors or @model.validate()
      if clientSideValidationErrors
        myError = @getMyError clientSideValidationErrors
        if myError then @validationError(myError) else @validationError()
      else
        @validationError()

    # This may need to be overridden in sub-classes.
    getMyError: (errorObject) -> errorObject[@attribute]

    # Display the validation error display, or remove it if there isn't an error.
    validationError: (error) ->
      $validationContainer = @$ '.dative-field-validation-container'
      if error
        @$('.dative-field-validation-error-message').html(
          "#{@context.label}: #{error}")
        # The validation error <div> might be in the process of sliding up;
        # therefore we have to check for an animation queue and clear it.
        queue = $validationContainer.queue()
        $validationContainer.stop true, true
        if $validationContainer.is ':hidden' or queue
          $validationContainer.slideDown()
      else
        @$('.dative-field-validation-error-message').empty()
        if $validationContainer.is ':visible'
          $validationContainer.slideUp()

    # If the input view returns a relational id from the DOM, then using this
    # in an override of `getValueFromDOM` will convert that id to an object.
    getValueFromRelationalIdFromDOM: (valueFromDOM) ->
      result = {}
      try
        idFromDOM = Number valueFromDOM[@context.attribute]
        options = @context.options[@optionsAttribute]
        value = _.findWhere options, {id: idFromDOM}
        result[@context.attribute] = value
      catch
        result[@context.attribute] = undefined
      result

    # If the input view returns an array of relational ids from the DOM, then
    # using this in an override of `getValueFromDOM` will convert that array to
    # an array of objects.
    getValueFromArrayOfRelationalIdsFromDOM: (valueFromDOM) ->
      result = {}
      result[@context.attribute] = []
      try
        arrayOfIdsFromDOM = valueFromDOM[@context.attribute]
        options = @context.options[@optionsAttribute]
        value = (o for o in options when o.id in arrayOfIdsFromDOM)
        result[@context.attribute] = value
      result

    disable: ->
      @inputView?.disable()

    enable: ->
      @inputView?.enable()

    ############################################################################
    # Helper methods for building a template context out of the form @model and
    # the supplied @attribute.
    ############################################################################

    # Value for the HTML name attribute of the input; just `attribute`.
    getName: (attribute=@attribute) -> attribute

    # CSS class for the input; just `attribute` in hyphen-case.
    getClass: (attribute=@attribute) -> @hyphenCaseify attribute

    # Get `attribute` in hyphen-case.
    hyphenCaseify: (attribute) ->
      switch @activeServerType
        when 'FieldDB' then @utils.camel2hyphen attribute
        when 'OLD' then @utils.snake2hyphen attribute
        else 'default'

    # HTML label text; just `attribute` in regular case.
    # TODO: do something more intelligent by trying to get FieldDB datumField
    # human-friendly labels.
    getLabel: (attribute=@attribute) ->
      switch @activeServerType
        when 'FieldDB' then @utils.camel2regular attribute
        when 'OLD' then @utils.snake2regular attribute
        else 'default'

    refreshTooltip: ->
      if @tooltipIsRefreshable then @labelView.refreshTooltip @getTooltip()

    # The tooltip (the HTML title attribute) for both the label and the input.
    getTooltip: (attribute=@attribute) ->
      switch @activeServerType
        when 'FieldDB' then @getFieldDBAttributeTooltip attribute, @resource
        when 'OLD' then @getOLDAttributeTooltip attribute, @resource
        else 'default'

    # Get the value to go in the input from the model. See the form model for
    # `getDatumValueSmart` for FieldDB form/datum models.
    getValue: (attribute=@attribute) ->
      switch @activeServerType
        when 'FieldDB' then @model.getDatumValueSmart attribute
        when 'OLD' then @model.get attribute
        else ''

    # If `options.grammaticalities` is an array, return it with '' as its first
    # member and all other empty strings removed. Useful for grammaticality
    # <select>s for OLD apps where the '' grammatical value may be left
    # implicit.
    addGrammaticalToGrammaticalities: (options) ->
      if options?.grammaticalities
        if @utils.type options.grammaticalities is 'array'
          tmp = (g for g in options.grammaticalities if g isnt '')
          options.grammaticalities = [''].concat tmp
      options

    defaultSelectValueGetter: (o) ->
      try
        o.id
      catch
        null

    defaultSelectTextGetter: (o) ->
      try
        o.name
      catch
        'no text for option'

