define [
  'backbone'
  './field'
  './translations-input-set'
], (Backbone, FieldView, TranslationsInputSetView) ->

  # Translations Field View
  # -----------------------
  #
  # A field view specifically for an array of translation objects, i.e.,
  #
  #   translations = [
  #     {
  #       transcription: 'dog',
  #       grammaticality: ''
  #     },
  #     {
  #       transcription: 'wolf',
  #       grammaticality: '*'
  #     }
  #   ]
  #
  # The HTML that this view governs consists of:
  #
  # - a label (built by the base class `FieldView`)
  # - an input collection (i.e., a set if input sets, one for each translation)
  #   governed by an instance of `TranslationsInputSetView`.
  #
  # NOTE: the translation's `grammaticality` would be more accurately
  # labeled as `acceptibility`; however, this is an issue with the OLD data
  # structure that I am accommodating here for now.

  class TranslationsFieldView extends FieldView

    getInputView: ->
      new TranslationsInputSetView @context

    getContext: ->
      context = super
      context.translationSelectAttribute = 'grammaticality'
      context.selectOptionsAttribute = 'grammaticalities'
      context.translationTextareaAttribute = 'transcription'
      context

