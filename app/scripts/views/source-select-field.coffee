define [
  './select-field'
  './../utils/bibtex'
], (SelectFieldView, BibTeXUtils) ->

  # Source Select(menu) Field View
  # ------------------------------
  #
  # A specialized SelectFieldView for OLD source objects, i.e,. texts such
  # as Uhlenbeck (1917). The only modification of the base class is that a
  # `selectTextGetter` is supplied, i.e., a function that takes a person
  # object and returns a string to go between <option> and </option>.

  class SourceSelectFieldView extends SelectFieldView

    initialize: (options) ->
      options.selectTextGetter = (option) ->
        "#{option.citationFormAuthor} (#{option.citationFormYear})"
      super options

    # Return the options for this source select field. Here we sort the source
    # options by author (in citation form, e.g., "Chomsky and Halle (1968)")
    # and we give them two new attributes for the convenience of
    # `@selectTextGetter`.
    getSelectOptions: ->
      r = @options[@optionsAttribute] or []
      sortedOptions = []
      for option in r
        citationFormAuthor = BibTeXUtils.getAuthor option
        option.citationFormAuthor = citationFormAuthor
        option.citationFormYear = BibTeXUtils.getYear option
        sortedOptions.push [citationFormAuthor.toLowerCase(), option]
      sortedOptions.sort()
      (o[1] for o in sortedOptions)

    getValueFromDOM: ->
      @getValueFromRelationalIdFromDOM super

