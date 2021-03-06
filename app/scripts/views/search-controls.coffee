define [
  './controls'
  './count-search-results-control'
  './browse-search-results-control'
], (ControlsView, CountSearchResultsControlView,
  BrowseSearchResultsControlView) ->

  # Search Controls View
  # ----------------------------
  #
  # View for a widget containing inputs and controls for manipulating the extra
  # actions of a search resource. These actions are
  #
  # 1. Browse the results of a search.
  # 2. Count the number of results that a search returns.

  class SearchControlsView extends ControlsView

    actionViewClasses: [
      BrowseSearchResultsControlView
      CountSearchResultsControlView
    ]

