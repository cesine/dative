define [], ->

  # Application-wide keyboard shortcuts are defined here. `MainMenuView` uses
  # this array of objects in its `keyboardShortcuts` method.

  [
    shortcut: 'ctrl+,'
    event: 'request:applicationSettings'
  ,
    shortcut: 'ctrl+h'
    event: 'request:home'
  ,
    shortcut: 'ctrl+p'
    event: 'request:pages'
  ,
    shortcut: 'ctrl+c'
    old:
      event: 'request:subcorporaBrowse'
    fielddb:
      event: 'request:corporaBrowse'
  ,
    shortcut: 'ctrl+r'
    event: 'request:openRegisterDialogBox'
  ,
    shortcut: 'ctrl+a'
    event: 'request:formAdd'
  ,
    shortcut: 'ctrl+s'
    event: 'request:searchesBrowse'
  ,
    shortcut: 'ctrl+b'
    event: 'request:formsBrowse'
  ,
    shortcut: 'ctrl+f'
    event: 'request:phonologiesBrowse'
  ,
    shortcut: 'ctrl+m'
    event: 'request:morphologiesBrowse'
  ,
    shortcut: 'ctrl+z'
    event: 'request:languageModelsBrowse'
  ,
    shortcut: 'ctrl+y'
    event: 'request:morphologicalParsersBrowse'
  ,
    shortcut: 'ctrl+?'
    event: 'request:toggleHelpDialogBox'
  ,
    shortcut: 'ctrl+l'
    event: 'request:openLoginDialogBox'
  ]
