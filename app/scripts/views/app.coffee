define [
  'backbone'
  'FieldDB'
  './../routes/router'
  './base'
  './mainmenu'
  './notifier'
  './login-dialog'
  './register-dialog'
  './alert-dialog'
  './help-dialog'
  './resource-displayer-dialog'
  './application-settings'
  './pages'
  './home'
  './form-add'
  './forms-search'
  './forms'
  './subcorpora'
  './phonologies'
  './morphologies'
  './language-models'
  './morphological-parsers'
  './corpora'
  './searches'
  './../models/application-settings'
  './../models/form'
  './../utils/globals'
  './../templates/app'
], (Backbone, FieldDB, Workspace, BaseView, MainMenuView, NotifierView,
  LoginDialogView, RegisterDialogView, AlertDialogView, HelpDialogView,
  ResourceDisplayerDialogView, ApplicationSettingsView, PagesView,
  HomePageView, FormAddView, FormsSearchView, FormsView, SubcorporaView,
  PhonologiesView, MorphologiesView, LanguageModelsView,
  MorphologicalParsersView, CorporaView, SearchesView,
  ApplicationSettingsModel, FormModel, globals, appTemplate) ->

  # App View
  # --------
  #
  # This is the spine of the application. Only one AppView object is created
  # and it controls the creation and rendering of all of the subviews that
  # control the content in the body of the page.

  class AppView extends BaseView

    template: appTemplate
    el: '#dative-client-app'

    initialize: (options) ->
      @router = new Workspace()
      @getApplicationSettings options
      globals.applicationSettings = @applicationSettings
      @overrideFieldDBNotificationHooks()
      @initializePersistentSubviews()
      @listenToEvents()
      @render()
      @setTheme()
      Backbone.history.start()
      @showHomePageView()

    resources: [
      'subcorpus'
      'phonology'
      'morphology'
    ]

    events:
      'click': 'bodyClicked'

    render: ->
      if window.location.hostname is ['localhost', '127.0.0.1']
        setTimeout ->
          console.clear()
        , 2000
      @$el.html @template()
      @renderPersistentSubviews()
      @matchWindowDimensions()
      @

    listenToEvents: ->
      @listenTo @mainMenuView, 'request:home', @showHomePageView
      @listenTo @mainMenuView, 'request:applicationSettings',
        @showApplicationSettingsView
      @listenTo @mainMenuView, 'request:openLoginDialogBox', @toggleLoginDialog
      @listenTo @mainMenuView, 'request:toggleHelpDialogBox', @toggleHelpDialog
      @listenTo @mainMenuView, 'request:openRegisterDialogBox',
        @toggleRegisterDialog
      @listenTo @mainMenuView, 'request:corporaBrowse', @showCorporaView
      @listenTo @mainMenuView, 'request:formAdd', @showNewFormView
      @listenTo @mainMenuView, 'request:formsBrowse', @showFormsView
      @listenTo Backbone, 'request:formsBrowseSearchResults',
        @showFormsSearchResultsBrowseView
      @listenTo Backbone, 'request:formsBrowseCorpus',
        @showFormsCorpusBrowseView
      @listenTo @mainMenuView, 'request:formsSearch', @showFormsSearchView
      @listenTo @mainMenuView, 'request:subcorpusAdd', @showNewSubcorpusView
      @listenTo @mainMenuView, 'request:subcorporaBrowse', @showSubcorporaView
      @listenTo @mainMenuView, 'request:phonologyAdd', @showNewPhonologyView
      @listenTo @mainMenuView, 'request:phonologiesBrowse', @showPhonologiesView
      @listenTo @mainMenuView, 'request:morphologyAdd', @showNewMorphologyView
      @listenTo @mainMenuView, 'request:morphologiesBrowse',
        @showMorphologiesView
      @listenTo @mainMenuView, 'request:languageModelsBrowse',
        @showLanguageModelsView
      @listenTo @mainMenuView, 'request:morphologicalParsersBrowse',
        @showMorphologicalParsersView
      @listenTo @mainMenuView, 'request:searchesBrowse',
        @showSearchesView
      @listenTo @mainMenuView, 'request:pages', @showPagesView

      @listenTo @router, 'route:home', @showHomePageView
      @listenTo @router, 'route:applicationSettings',
        @showApplicationSettingsView
      @listenTo @router, 'route:openLoginDialogBox', @toggleLoginDialog
      @listenTo @router, 'route:openRegisterDialogBox', @toggleRegisterDialog
      @listenTo @router, 'route:corporaBrowse', @showCorporaView
      @listenTo @router, 'route:formAdd', @showNewFormView
      @listenTo @router, 'route:formsBrowse', @showFormsView
      @listenTo @router, 'route:formsSearch', @showFormsSearchView
      @listenTo @router, 'route:pages', @showPagesView

      @listenTo @loginDialog, 'request:openRegisterDialogBox',
        @toggleRegisterDialog
      @listenTo Backbone, 'loginSuggest', @openLoginDialogWithDefaults
      @listenTo Backbone, 'authenticateSuccess', @authenticateSuccess
      @listenTo Backbone, 'authenticate:success', @authenticateSuccess
      @listenTo Backbone, 'authenticate:mustconfirmidentity', @authenticateConfirmIdentity
      @listenTo Backbone, 'logoutSuccess', @logoutSuccess
      @listenTo Backbone, 'logout:success', @logoutSuccess
      @listenTo Backbone, 'useFieldDBCorpus', @useFieldDBCorpus
      @listenTo Backbone, 'applicationSettings:changeTheme', @changeTheme

      @listenTo Backbone, 'formsView:expandAllForms', @setAllFormsExpanded
      @listenTo Backbone, 'formsView:collapseAllForms', @setAllFormsCollapsed
      @listenTo Backbone, 'formsView:itemsPerPageChange', @setFormsItemsPerPage
      @listenTo Backbone, 'formsView:hideAllLabels',
        @setFormsPrimaryDataLabelsHidden
      @listenTo Backbone, 'formsView:showAllLabels',
        @setFormsPrimaryDataLabelsVisible
      @listenTo Backbone, 'showResourceInDialog', @showResourceInDialog

      @listenToResources()

    # TODO/QUESTION: why not just listen on the resources subclass instead of
    # on Backbone with all of this complex naming stuff?
    listenToResources: ->
      for resource in @resources
        resourcePlural = @utils.pluralize resource
        resourcePluralCapitalized = @utils.capitalize resourcePlural
        @listenTo Backbone,
          "#{resourcePlural}View:expandAll#{resourcePluralCapitalized}",
          @["setAll#{resourcePluralCapitalized}Expanded"]
        @listenTo Backbone,
          "#{resourcePlural}View:collapseAll#{resourcePluralCapitalized}",
          @["setAll#{resourcePluralCapitalized}Collapsed"]
        @listenTo Backbone, "#{resourcePlural}View:itemsPerPageChange",
          @["set#{resourcePluralCapitalized}ItemsPerPage"]
        @listenTo Backbone, "#{resourcePlural}View:hideAllLabels",
          @["set#{resourcePluralCapitalized}PrimaryDataLabelsHidden"]
        @listenTo Backbone, "#{resourcePlural}View:showAllLabels",
          @["set#{resourcePluralCapitalized}PrimaryDataLabelsVisible"]

    initializePersistentSubviews: ->
      @mainMenuView = new MainMenuView model: @applicationSettings
      @loginDialog = new LoginDialogView model: @applicationSettings
      @registerDialog = new RegisterDialogView model: @applicationSettings
      @alertDialog = new AlertDialogView model: @applicationSettings
      @helpDialog = new HelpDialogView()
      @notifier = new NotifierView()
      @resourceDisplayerDialog = new ResourceDisplayerDialogView()

    renderPersistentSubviews: ->
      @mainMenuView.setElement(@$('#mainmenu')).render()
      @loginDialog.setElement(@$('#login-dialog-container')).render()
      @registerDialog.setElement(@$('#register-dialog-container')).render()
      @alertDialog.setElement(@$('#alert-dialog-container')).render()
      @helpDialog.setElement(@$('#help-dialog-container'))
      @resourceDisplayerDialog
        .setElement(@$('#resource-displayer-dialog-container'))
        .render()
      @notifier.setElement(@$('#notifier-container')).render()

      @rendered @mainMenuView
      @rendered @loginDialog
      @rendered @registerDialog
      @rendered @alertDialog
      @rendered @notifier
      @rendered @resourceDisplayerDialog

    renderHelpDialog: ->
      @helpDialog.render()
      @rendered @helpDialog

    bodyClicked: ->
      Backbone.trigger 'bodyClicked' # Mainmenu superclick listens for this

    useFieldDBCorpus: (corpusId) ->
      currentlyActiveFieldDBCorpus = @activeFieldDBCorpus
      fieldDBCorporaCollection = @corporaView?.collection
      @activeFieldDBCorpus = fieldDBCorporaCollection?.findWhere
        pouchname: corpusId
      @applicationSettings.save
        'activeFieldDBCorpus': corpusId
        'activeFieldDBCorpusTitle': @activeFieldDBCorpus.get 'title'
        'activeFieldDBCorpusModel': @activeFieldDBCorpus # TODO: FIX THIS ABERRATION!
      globals.activeFieldDBCorpus = @activeFieldDBCorpus
      if currentlyActiveFieldDBCorpus is @activeFieldDBCorpus
        @showFormsView fieldDBCorpusHasChanged: false
      else
        # @mainMenuView.activeFieldDBCorpusChanged @activeFieldDBCorpus.get('title')
        @showFormsView fieldDBCorpusHasChanged: true

    logoutSuccess: ->
      @closeVisibleView()
      @corporaView = null
      @showHomePageView()

    activeServerType: ->
      try
        @applicationSettings.get('activeServer').get 'type'
      catch
        null

    authenticateSuccess: ->
      activeServerType = @activeServerType()
      switch activeServerType
        when 'FieldDB' 
          if @applicationSettings.get 'fieldDBApplication' != FieldDB.FieldDBObject.application
            @applicationSettings.set 'fieldDBApplication', FieldDB.FieldDBObject.application
          @showCorporaView()
        when 'OLD' then @showFormsView()
        else console.log 'Error: you logged in to a non-FieldDB/non-OLD server (?).'

    authenticateConfirmIdentity: (message) =>
      message = message or 'We need to make sure this is you. Confirm your
        password to continue.'
      if not @originalMessage then @originalMessage = message
      @displayConfirmIdentityDialog(
          message
        ,
          (loginDetails) =>
            console.log 'no problem.. can keep working'
            fieldDBApplication = @applicationSettings.get('fieldDBApplication')
            @set
              username: fieldDBApplication.authentication.user.username,
              loggedInUser: fieldDBApplication.authentication.user
            @save()
            delete @originalMessage
        ,
          (loginDetails) =>
            if @confirmIdentityErrorCount > 3
              console.log ' In this case of confirming identity, the user MUST
                authenticate. If they cant remember their password, after 4
                attempts, log them out.'
              delete @originalMessage
              Backbone.trigger 'authenticate:logout'
            console.log 'Asking again'
            @confirmIdentityErrorCount = @confirmIdentityErrorCount or 0
            @confirmIdentityErrorCount++
            @authenticateConfirmIdentity "#{@originalMessage}
              #{loginDetails.userFriendlyErrors.join ' '}"
      )

    # Set `@applicationSettings`
    getApplicationSettings: (options) ->
      # Allowing an app settings model in the options facilitates testing.
      if options?.applicationSettings
        @applicationSettings = options.applicationSettings
      else
        @applicationSettings = new ApplicationSettingsModel()
        @applicationSettings.fetch()

    # Size the #appview div relative to the window size
    matchWindowDimensions: ->
      @$('#appview').css height: $(window).height() - 50
      $(window).resize =>
        @$('#appview').css height: $(window).height() - 50

    renderVisibleView: (taskId=null) ->
      @visibleView.setElement @$('#appview')
      @visibleView.render taskId
      @rendered @visibleView

    closeVisibleView: ->
      if @visibleView
        @visibleView.close()
        @closed @visibleView

    loggedIn: -> 
      if @applicationSettings.get('fieldDBApplication') and
      @applicationSettings.get('fieldDBApplication').authentication and 
      @applicationSettings.get('fieldDBApplication').authentication.user and 
      @applicationSettings.get('fieldDBApplication').authentication.user.authenticated
        @applicationSettings.set 'loggedIn', true
        @applicationSettings.set 'loggedInUserRoles', @applicationSettings.get('fieldDBApplication').authentication.user.roles
      @applicationSettings.get 'loggedIn'

    ############################################################################
    # Methods for showing the main "pages" of Dative                           #
    ############################################################################

    showApplicationSettingsView: ->
      if @applicationSettingsView and
      @visibleView is @applicationSettingsView then return
      @router.navigate 'application-settings'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening application settings', taskId
      @closeVisibleView()
      if not @applicationSettingsView
        @applicationSettingsView = new ApplicationSettingsView(
          model: @applicationSettings)
      @visibleView = @applicationSettingsView
      @renderVisibleView taskId

    showFormsView: (options) ->
      if not @loggedIn() then return
      if options?.search then @visibleView = null
      if @formsView and @visibleView is @formsView then return
      @router.navigate 'forms-browse'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening form browse view', taskId
      @closeVisibleView()
      if @formsView
        if @activeServerType() is 'FieldDB' and options?.fieldDBCorpusHasChanged
          @formsView.close()
          @closed @formsView
          @formsView = new FormsView
            applicationSettings: @applicationSettings
            activeFieldDBCorpus: @activeFieldDBCorpus
      else
        @formsView = new FormsView
          applicationSettings: @applicationSettings
          activeFieldDBCorpus: @activeFieldDBCorpus
      @visibleView = @formsView
      # This is relevant if the user is trying to add a new form.
      if options?.showNewFormView
        @formsView.newFormViewVisible = true
        @formsView.weShouldFocusFirstAddViewInput = true
      if options?.search
        @formsView.setSearch options.search
      else
        @formsView.deleteSearch()
      if options?.corpus
        @formsView.setCorpus options.corpus
      else
        @formsView.deleteCorpus()
      @renderVisibleView taskId

    showFormsSearchResultsBrowseView: (options) ->
      @showFormsView options

    showFormsCorpusBrowseView: (options) ->
      @showFormsView options

    showNewFormView: ->
      if not @loggedIn() then return
      if @formsView and @visibleView is @formsView
        @visibleView.toggleNewResourceViewAnimate()
      else
        @showFormsView showNewFormView: true

    # Show the page for browsing subcorpora (i.e., OLD corpora) AND open upt
    # the interface for creating a new subcorpus.
    showNewSubcorpusView: ->
      if not @loggedIn() then return
      if @subcorporaView and @visibleView is @subcorporaView
        @visibleView.toggleNewSubcorpusViewAnimate()
      else
        @showSubcorporaView showNewSubcorpusView: true

    # Show the page for browsing subcorpora (i.e., OLD corpora).
    showSubcorporaView: (options) ->
      if not @loggedIn() then return
      if @subcorporaView and @visibleView is @subcorporaView then return
      @router.navigate 'subcorpora-browse'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening corpora browse view', taskId
      @closeVisibleView()
      if not @subcorporaView
        @subcorporaView = new SubcorporaView()
      @visibleView = @subcorporaView
      # This is relevant if the user is trying to add a new corpus.
      if options?.showNewSubcorpusView
        @subcorporaView.newSubcorpusViewVisible = true
        @subcorporaView.weShouldFocusFirstAddViewInput = true
      @renderVisibleView taskId

    # Show the page for browsing phonologies AND open up the interface for
    # creating a new phonology.
    showNewPhonologyView: ->
      if not @loggedIn() then return
      if @phonologiesView and @visibleView is @phonologiesView
        @visibleView.toggleNewResourceViewAnimate()
      else
        @showPhonologiesView showNewPhonologyView: true

    # Show the page for browsing phonologies.
    showPhonologiesView: (options) ->
      if not @loggedIn() then return
      if @phonologiesView and @visibleView is @phonologiesView then return
      @router.navigate 'phonologies-browse'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening phonologies browse view', taskId
      @closeVisibleView()
      if not @phonologiesView
        @phonologiesView = new PhonologiesView()
      @visibleView = @phonologiesView
      # This is relevant if the user is trying to add a new corpus.
      if options?.showNewPhonologyView
        @phonologiesView.newResourceViewVisible = true
        @phonologiesView.weShouldFocusFirstAddViewInput = true
      @renderVisibleView taskId

    # Show the page for browsing morphologies AND open up the interface for
    # creating a new morphology.
    showNewMorphologyView: ->
      if not @loggedIn() then return
      if @morphologiesView and @visibleView is @morphologiesView
        @visibleView.toggleNewResourceViewAnimate()
      else
        @showMorphologiesView showNewMorphologyView: true

    # Show the page for browsing morphologies.
    showMorphologiesView: (options) ->
      if not @loggedIn() then return
      if @morphologiesView and @visibleView is @morphologiesView then return
      @router.navigate 'morphologies-browse'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening morphologies browse view', taskId
      @closeVisibleView()
      if not @morphologiesView
        @morphologiesView = new MorphologiesView()
      @visibleView = @morphologiesView
      # This is relevant if the user is trying to add a new morphology.
      if options?.showNewMorphologyView
        @morphologiesView.newResourceViewVisible = true
        @morphologiesView.weShouldFocusFirstAddViewInput = true
      @renderVisibleView taskId

    # Show the page for browsing morpheme language models.
    showLanguageModelsView: (options) ->
      if not @loggedIn() then return
      if @languageModelsView and
      @visibleView is @languageModelsView
        return
      @router.navigate 'language-models-browse'
      taskId = @guid()
      Backbone.trigger(
        'longTask:register', 'Opening language models browse view', taskId)
      @closeVisibleView()
      if not @languageModelsView
        @languageModelsView = new LanguageModelsView()
      @visibleView = @languageModelsView
      @renderVisibleView taskId

    # Show the page for browsing morphological parsers.
    showMorphologicalParsersView: (options) ->
      if not @loggedIn() then return
      if @morphologicalParsersView and
      @visibleView is @morphologicalParsersView
        return
      @router.navigate 'morphological-parsers-browse'
      taskId = @guid()
      Backbone.trigger('longTask:register', 'Opening morphological parsers
        browse view', taskId)
      @closeVisibleView()
      if not @morphologicalParsersView
        @morphologicalParsersView = new MorphologicalParsersView()
      @visibleView = @morphologicalParsersView
      @renderVisibleView taskId

    # Show the page for browsing searches.
    showSearchesView: (options) ->
      if not @loggedIn() then return
      if @searchesView and
      @visibleView is @searchesView
        return
      @router.navigate 'searches-browse'
      taskId = @guid()
      Backbone.trigger('longTask:register', 'Opening searches browse view',
        taskId)
      @closeVisibleView()
      if not @searchesView
        @searchesView = new SearchesView()
      @visibleView = @searchesView
      @renderVisibleView taskId

    # Put out of use for now. Now adding a form is done via the browse
    # interface. See `showFormAddView`.
    showFormAddView_OLD: ->
      if not @loggedIn() then return
      if @formAddView and @visibleView is @formAddView then return
      @router.navigate 'form-add'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening form add view', taskId
      @closeVisibleView()
      if not @formAddView
        @formAddView = new FormAddView(model: new FormModel())
      @visibleView = @formAddView
      @renderVisibleView taskId

    showFormsSearchView: ->
      if not @loggedIn() then return
      if @formsSearchView and @visibleView is @formsSearchView then return
      @router.navigate 'forms-search'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening form search view', taskId
      @closeVisibleView()
      if not @formsSearchView then @formsSearchView = new FormsSearchView()
      @visibleView = @formsSearchView
      @renderVisibleView taskId

    showPagesView: ->
      if not @loggedIn() then return
      if @pagesView and @visibleView is @pagesView then return
      @router.navigate 'pages'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening pages view', taskId
      @closeVisibleView()
      if not @pagesView then @pagesView = new PagesView()
      @visibleView = @pagesView
      @renderVisibleView taskId

    showHomePageView: ->
      if @homePageView and @visibleView is @homePageView then return
      @router.navigate 'home'
      @closeVisibleView()
      if not @homePageView then @homePageView = new HomePageView()
      @visibleView = @homePageView
      @renderVisibleView()

    showCorporaView: ->
      if not @loggedIn() then return
      if @corporaView and @visibleView is @corporaView then return
      if @visibleView then @visibleView.spin()
      @router.navigate 'corpora'
      taskId = @guid()
      Backbone.trigger 'longTask:register', 'Opening corpora view', taskId
      @closeVisibleView()
      if not @corporaView
        @corporaView = new CorporaView
          applicationSettings: @applicationSettings
          activeFieldDBCorpus: @activeFieldDBCorpus
      if @visibleView then @visibleView.stopSpin()
      @visibleView = @corporaView
      @renderVisibleView taskId

    # Open/close the login dialog box
    toggleLoginDialog: ->
      Backbone.trigger 'loginDialog:toggle'

    openLoginDialogWithDefaults: (username, password) ->
      @loginDialog.dialogOpenWithDefaults
        username: username
        password: password

    # Open/close the register dialog box
    toggleRegisterDialog: ->
      Backbone.trigger 'registerDialog:toggle'

    # Open/close the alert dialog box
    toggleAlertDialog: ->
      Backbone.trigger 'alertDialog:toggle'

    # Open/close the help dialog box
    toggleHelpDialog: ->
      if not @helpDialog.hasBeenRendered
        @renderHelpDialog()
      Backbone.trigger 'helpDialog:toggle'

    ############################################################################
    # Change the jQuery UI CSS Theme
    ############################################################################

    # Change the theme if we're using the non-default one on startup.
    setTheme: ->
      activeTheme = @applicationSettings.get 'activeJQueryUITheme'
      defaultTheme = @applicationSettings.get 'defaultJQueryUITheme'
      if activeTheme isnt defaultTheme
        @changeTheme()

    changeTheme: (event) ->

      # This is harder than it might at first seem.
      # Algorithm:
      # 1. get new CSS URL from selectmenu
      # 2. remove the current jQueryUI CSS <link>
      # 3. add a new jQueryUI CSS <link> with the new URL in its `href`
      # 4. ***CRUCIAL:*** when <link> `load` event fires, we ...
      # 5. get `BaseView.constructor` to refresh its `_jQueryUIColors`, which ...
      # 6. triggers a Backbone event indicating that the jQueryUI theme has changed, which ...
      # 7. causes `MainMenuView` to re-render.
      #
      # WARN: works for me on Mac with FF, Ch & Sa. Unsure of
      # cross-platform/browser support. May want to do feature detection and
      # employ a mixture of strategies 1-4.

      themeName = @applicationSettings.get 'activeJQueryUITheme'
      # TODO: this URL stuff should be in model
      newJQueryUICSSURL = "http://code.jquery.com/ui/1.11.2/themes/#{themeName}/jquery-ui.min.css"
      $jQueryUILinkElement = $('#jquery-ui-css')
      $jQueryUILinkElement.remove()
      $jQueryUILinkElement.attr href: newJQueryUICSSURL
      linkHTML = $jQueryUILinkElement.get(0).outerHTML
      $('#font-awesome-css').after linkHTML
      outerCallback = =>
        innerCallback = =>
          Backbone.trigger 'application-settings:jQueryUIThemeChanged'
        @constructor.refreshJQueryUIColors innerCallback
      @listenForLinkOnload outerCallback

      # Remaining TODOs:
      # 1. disable this feature when there is no Internet connection
      # 2. focus highlight doesn't match on login dialog (probably because it
      #    should be re-rendered after theme change)

    # Four strategies for detecting that a new CSS <link> has loaded.
    ############################################################################
    #
    # See http://www.phpied.com/when-is-a-stylesheet-really-loaded/

    # strategy #1
    listenForLinkOnload: (callback) ->
      link = document.getElementById 'jquery-ui-css'
      if link
        link.onload = -> callback()

    # strategy #2
    addEventListenerToLink: (callback) ->
      link = document.getElementById 'jquery-ui-css'
      eventListener = -> callback()
      if link && link.addEventListener
        link.addEventListener 'load', eventListener, false

    # strategy #3
    listenForReadyStateChange: (callback) ->
      link = document.getElementById 'jquery-ui-css'
      if link
        link.onreadystatechange = ->
          state = link.readyState
          if state is 'loaded' or state is 'complete'
            link.onreadystatechange = null
            callback()

    # strategy #4
    checkForChangeInDocumentStyleSheets: (callback) ->
      cssnum = document.styleSheets.length
      func = ->
        if document.styleSheets.length > cssnum
          callback()
          clearInterval ti
      ti = setInterval func, 10

    ############################################################################
    # FieldDB .bug, .warn and .confirm hooks
    ############################################################################
    #
    overrideFieldDBNotificationHooks: ->
      # Overriding FieldDB's logging hooks to do nothing
      FieldDB.FieldDBObject.verbose = -> {}
      FieldDB.FieldDBObject.debug = -> {}
      FieldDB.FieldDBObject.todo = -> {}
      FieldDB.FieldDBObject.bug = @displayBugReportDialog
      FieldDB.FieldDBObject.warn = @displayWarningMessagesDialog
      FieldDB.FieldDBObject.confirm = @displayConfirmDialog
      # FieldDB.FieldDBObject.prompt = @displayPromptDialog // TODO there is a problem with scoping 'Uncaught TypeError: this.listenTo is not a function' -GC

    displayBugReportDialog: (message, optionalLocale) =>
      deferred = FieldDB.Q.defer()
      messageChannel = "bug:#{message?.replace /[^A-Za-z]/g, ''}"
      @listenTo Backbone, messageChannel, ->
        window.open(
          "https://docs.google.com/forms/d/18KcT_SO8YxG8QNlHValEztGmFpEc4-ZrjWO76lm0mUQ/viewform")
        deferred.resolve
          message: message
          optionalLocale: optionalLocale
          response: true

      options =
        text: message
        confirm: false
        confirmEvent: messageChannel
        confirmArgument: message
      Backbone.trigger 'openAlertDialog', options

      return deferred.promise

    displayWarningMessagesDialog: (message, message2, message3, message4) ->
      console.log message, message2, message3, message4

    displayConfirmDialog: (message, optionalLocale) =>
      # TODO @jrwdunham @cesine: figure out how i18n/localization works in
      # Dative.
      deferred = FieldDB.Q.defer()
      messageChannel = "confirm:#{message?.replace /[^A-Za-z]/g, ''}"

      @listenTo Backbone, messageChannel, ->
        deferred.resolve
          message: message
          optionalLocale: optionalLocale
          response: true

      @listenTo Backbone, "cancel#{messageChannel}", ->
        deferred.reject
          message: message
          optionalLocale: optionalLocale
          response: false

      options =
        text: message
        confirm: true
        confirmEvent: messageChannel
        cancelEvent: "cancel#{messageChannel}"
        confirmArgument: message
        cancelArgument: message
      Backbone.trigger 'openAlertDialog', options

      deferred.promise

    displayPromptDialog: (message, optionalLocale) ->
      deferred = FieldDB.Q.defer()
      messageChannel = "prompt:#{message?.replace /[^A-Za-z]/g, ''}"

      @listenTo Backbone, messageChannel, (userInput) ->
        deferred.resolve
          message: message
          optionalLocale: optionalLocale
          response: userInput

      @listenTo Backbone, "cancel#{messageChannel}", ->
        deferred.reject
          message: message
          optionalLocale: optionalLocale
          response: ""

      options =
        text: message
        confirm: true
        prompt: true
        confirmEvent: messageChannel
        cancelEvent: 'cancel' + messageChannel
        confirmArgument: message
        cancelArgument: message
      Backbone.trigger 'openAlertDialog', options

      deferred.promise

    displayConfirmIdentityDialog: (message, successCallback, failureCallback, cancelCallback) =>
      cancelCallback = cancelCallback or failureCallback
      if @applicationSettings.get 'fieldDBApplication' != FieldDB.FieldDBObject.application
        @applicationSettings.set 'fieldDBApplication', FieldDB.FieldDBObject.application
      @displayPromptDialog(message).then(
        (dialog) =>
          @applicationSettings
            .get('fieldDBApplication')
            .authentication
            .confirmIdentity(password: dialog.response)
            .then successCallback, failureCallback 
      ,
        cancelCallback
      )

    ############################################################################
    # Persist application settings.
    ############################################################################

    # Change `attribute` to `value` in applicationSettings.formsDisplaySettings.
    changeFormsDisplaySetting: (attribute, value) ->
      try
        formsDisplaySettings = @applicationSettings.get 'formsDisplaySettings'
        formsDisplaySettings[attribute] = value
        @applicationSettings.save 'formsDisplaySettings', formsDisplaySettings

    # Set app settings' "all forms expanded" to true.
    setAllFormsExpanded: ->
      @changeFormsDisplaySetting 'allFormsExpanded', true

    # Set app settings' "all forms expanded" to false.
    setAllFormsCollapsed: ->
      @changeFormsDisplaySetting 'allFormsExpanded', false

    # Persist the new "items per page" to app settings.
    setFormsItemsPerPage: (newItemsPerPage) ->
      @changeFormsDisplaySetting 'itemsPerPage', newItemsPerPage

    # Set app settings' "primary data labels visible" to false.
    setFormsPrimaryDataLabelsHidden: ->
      @changeFormsDisplaySetting 'dataLabelsVisible', false

    # Set app settings' "primary data labels visible" to true.
    setFormsPrimaryDataLabelsVisible: ->
      @changeFormsDisplaySetting 'dataLabelsVisible', true


    # Change `attribute` to `value` in
    # applicationSettings.`resource`DisplaySettings.
    changeDisplaySetting: (resource, attribute, value) ->
      try
        displaySettings = @applicationSettings.get "#{resource}DisplaySettings"
        displaySettings[attribute] = value
        @applicationSettings.save "#{resource}DisplaySettings", displaySettings

    # Phonologies Settings
    ############################################################################

    # Set app settings' "all phonologies expanded" to true.
    setAllPhonologiesExpanded: ->
      @changeDisplaySetting 'phonologies', 'allPhonologiesExpanded', true

    # Set app settings' "all phonologies expanded" to false.
    setAllPhonologiesCollapsed: ->
      @changeDisplaySetting 'phonologies', 'allPhonologiesExpanded', false

    # Persist the new "items per page" to app settings.
    setPhonologiesItemsPerPage: (newItemsPerPage) ->
      @changeDisplaySetting 'phonologies', 'itemsPerPage', newItemsPerPage

    # Set app settings' "primary data labels visible" to false.
    setPhonologiesPrimaryDataLabelsHidden: ->
      @changeDisplaySetting 'phonologies', 'dataLabelsVisible', false

    # Set app settings' "primary data labels visible" to true.
    setPhonologiesPrimaryDataLabelsVisible: ->
      @changeDisplaySetting 'phonologies', 'dataLabelsVisible', true


    # Subcorpora Settings
    ############################################################################

    # Set app settings' "all subcorpora expanded" to true.
    setAllSubcorporaExpanded: ->
      @changeDisplaySetting 'subcorpora', 'allSubcorporaExpanded', true

    # Set app settings' "all subcorpora expanded" to false.
    setAllSubcorporaCollapsed: ->
      @changeDisplaySetting 'subcorpora', 'allSubcorporaExpanded', false

    # Persist the new "items per page" to app settings.
    setSubcorporaItemsPerPage: (newItemsPerPage) ->
      @changeDisplaySetting 'subcorpora', 'itemsPerPage', newItemsPerPage

    # Set app settings' "primary data labels visible" to false.
    setSubcorporaPrimaryDataLabelsHidden: ->
      @changeDisplaySetting 'subcorpora', 'dataLabelsVisible', false

    # Set app settings' "primary data labels visible" to true.
    setSubcorporaPrimaryDataLabelsVisible: ->
      @changeDisplaySetting 'subcorpora', 'dataLabelsVisible', true


    # Morphologies Settings
    ############################################################################

    # Set app settings' "all morphologies expanded" to true.
    setAllMorphologiesExpanded: ->
      @changeDisplaySetting 'morphologies', 'allMorphologiesExpanded', true

    # Set app settings' "all morphologies expanded" to false.
    setAllMorphologiesCollapsed: ->
      @changeDisplaySetting 'morphologies', 'allMorphologiesExpanded', false

    # Persist the new "items per page" to app settings.
    setMorphologiesItemsPerPage: (newItemsPerPage) ->
      @changeDisplaySetting 'morphologies', 'itemsPerPage', newItemsPerPage

    # Set app settings' "primary data labels visible" to false.
    setMorphologiesPrimaryDataLabelsHidden: ->
      @changeDisplaySetting 'morphologies', 'dataLabelsVisible', false

    # Set app settings' "primary data labels visible" to true.
    setMorphologiesPrimaryDataLabelsVisible: ->
      @changeDisplaySetting 'morphologies', 'dataLabelsVisible', true


    # Render the passed in resource view in the application-wide
    # `@resourceDisplayerDialog`
    showResourceInDialog: (resourceView, $target) ->
      Backbone.trigger 'resourceDisplayerDialog:show', resourceView, $target

