define [
  './resource'
  './file-add-widget'
  './field-display'
  './person-field-display'
  './date-field-display'
  './object-with-name-field-display'
  './array-of-objects-with-name-field-display'
  './bytes-field-display'
], (ResourceView, FileAddWidgetView, FieldDisplayView, PersonFieldDisplayView,
  DateFieldDisplayView, ObjectWithNameFieldDisplayView,
  ArrayOfObjectsWithNameFieldDisplayView, BytesFieldDisplayView) ->

  # File View
  # --------------
  #
  # For displaying individual files.

  class FileView extends ResourceView

    resourceName: 'file'

    resourceAddWidgetView: FileAddWidgetView

    # Attributes that are always displayed.
    primaryAttributes: [
      'filename'
    ]

    # Attributes that may be hidden.
    secondaryAttributes: [
      'size'
      'MIME_type'
      'name'
      'lossy_filename'
      'description'
      'utterance_type'
      'speaker'
      'elicitor'
      'tags'
      #'forms'
      'date_elicited'
      'url'
      'password'
      'parent_file'
      'start'
      'end'
      'enterer'
      'modifier'
      'datetime_entered'
      'datetime_modified'
      'UUID'
      'id'
    ]

    attribute2displayView:
      speaker: PersonFieldDisplayView
      elicitor: PersonFieldDisplayView
      enterer: PersonFieldDisplayView
      modifier: PersonFieldDisplayView
      date_elicited: DateFieldDisplayView
      datetime_entered: DateFieldDisplayView
      datetime_modified: DateFieldDisplayView
      size: BytesFieldDisplayView
      tags: ArrayOfObjectsWithNameFieldDisplayView

    MIMEType2type:
      'application/pdf': 'pdf'
      'image/gif': 'image'
      'image/jpeg': 'image'
      'image/png': 'image'
      'audio/mpeg': 'audio'
      'audio/ogg': 'audio'
      'audio/x-wav': 'audio'
      'video/mpeg': 'video'
      'video/mp4': 'video'
      'video/ogg': 'video'
      'video/quicktime': 'video'
      'video/x-ms-wmv': 'video'

    getHeaderTitle: ->
      MIMEType = @model.get 'MIME_type'
      if MIMEType and MIMEType of @MIMEType2type
        type = @MIMEType2type[MIMEType]
        iconI = "<i class='fa fa-fw fa-file-#{type}-o'></i>"
      else
        iconI = ''
      "File #{@model.get 'id'}#{iconI}"
