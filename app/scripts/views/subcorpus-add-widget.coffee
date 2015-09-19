define [
  './resource-add-widget'
  './textarea-field'
  './relational-select-field'
  './multi-element-tag-field'
  './search-select-via-search-field'
  './../models/subcorpus'
], (ResourceAddWidgetView, TextareaFieldView, RelationalSelectFieldView,
  MultiElementTagFieldView, SearchSelectViaSearchFieldView, SubcorpusModel) ->


  class TextareaFieldView255 extends TextareaFieldView

    initialize: (options) ->
      options.domAttributes =
        maxlength: 255
      super options


  # Subcorpus Add Widget View
  # --------------------------
  #
  # View for a widget containing inputs and controls for creating a new
  # subcorpus and updating an existing one.

  ##############################################################################
  # Subcorpus Add Widget
  ##############################################################################

  class SubcorpusAddWidgetView extends ResourceAddWidgetView

    resourceName: 'subcorpus'
    resourceModel: SubcorpusModel

    # Maps attributes to their appropriate FieldView subclasses.
    # This is where field-specific configuration should go.
    attribute2fieldView:
      name:        TextareaFieldView255
      tags:        MultiElementTagFieldView
      form_search: SearchSelectViaSearchFieldView
      #form_search: RelationalSelectFieldView

    primaryAttributes: [
      'name'
      'description'
      'content'
      'form_search'
      'tags'
    ]

    editableSecondaryAttributes: [ ]

