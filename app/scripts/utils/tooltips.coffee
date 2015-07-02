define ['./utils'], (utils) ->

  # Tooltips defined here, in one place. These are the HTML "title" attributes
  # that are transformed into jQueryUI tooltips. Consolidating them here is
  # good for future translation/localization, etc.
  #
  # This module returns a function that, when passed in a "dot notation" string
  # will return the appropriate tooltip function (or a default one, if the
  # requested tooltip does not exist. For example, to get the tooltip for the
  # syntactic category field of OLD forms:
  #
  #   tooltips('old.forms.syntactic_category')() #
  #
  # Some tooltips are functions that take an `options` argument. These functions
  # (generally) expect a `options.value` attribute that is the value of the
  # item being "tooltipped". Thus, if you pass a `Date` instance to the
  # `dateElicited` tooltip function, it will be used in the returned tooltip:
  #
  #   tooltips('fieldDB.forms.dateEntered') value: new Date()

  dateElicited =
    eng: (options) ->
      if options.value
        "This form was elicited on #{utils.humanDate options.value}"
      else
        'The date this form was elicited'

  datetimeEntered =
    eng: (options) ->
      if options.value and options.resourceName
        "This #{utils.camel2regular(utils.singularize(options.resourceName))}
          was entered on #{utils.humanDatetime options.value}"
      else
        "The date and time when this resource was entered"

  generateSucceeded =
    eng: (options) ->
      if 'value' of options
        if options.value is true
          "The most recent attempt to generate a FST script for this
            #{utils.camel2regular(utils.singularize(options.resourceName))} was
            successful."
        else
          "The most recent attempt to generate a FST script for this
            #{utils.camel2regular(utils.singularize(options.resourceName))} was
            NOT successful."
      else
        'Will be true if the last generate attempt succeeded; false otherwise.'

  compileSucceeded =
    eng: (options) ->
      if 'value' of options
        if options.value is true
          "The most recent attempt to compile the FST script of this
            #{utils.camel2regular(utils.singularize(options.resourceName))} was
            successful."
        else
          "The most recent attempt to compile the FST script for this
            #{utils.camel2regular(utils.singularize(options.resourceName))} was
            NOT successful."
      else
        'Will be true if the last generate attempt succeeded; false otherwise.'

  compileMessage =
    eng: (options) ->
      "The message returned by the OLD after an attempt to compile this
        #{utils.camel2regular(utils.singularize(options.resourceName))}."

  compileAttempt =
    eng: (options) ->
      "A unique value (a UUID) created by the OLD after each attempt to compile
        a #{utils.camel2regular(utils.singularize(options.resourceName))}."

  datetimeModified =
    eng: (options) ->
      if options.value and options.resourceName
        "This #{utils.camel2regular(utils.singularize(options.resourceName))}
          was last modified on #{utils.humanDatetime options.value}"
      else
        "The date and time when this resource was last modified"

  enterer =
    eng: (options) ->
      if options.resourceName
        tmp = utils.camel2regular(utils.singularize(options.resourceName))
      else
        tmp = 'resource'
      "The user who entered/created this #{tmp}. This value is
        specified automatically by the application."

  modifier =
    eng: (options) ->
      if options.resourceName
        tmp = utils.camel2regular(utils.singularize(options.resourceName))
      else
        tmp = 'resource'
      "The user who made the most recent modification to this #{tmp}. This
        value is specified automatically by the application."

  name =
    eng: (options) ->
      if options.resourceName
        resourceName =
          utils.camel2regular(utils.singularize(options.resourceName))
        resourceNamePlural = utils.camel2regular(options.resourceName)
      else
        resourceName = 'resource'
        resourceNamePlural = 'resources'
      "A name for the #{resourceName}. Each #{resourceName} must have a name and
        it must be unique among #{resourceNamePlural}."

  description =
    eng: (options) ->
      if options.resourceName
        "A description of the
          #{utils.camel2regular(utils.singularize(options.resourceName))}."
      else
        "A description of the resource."

  id =
    eng: (options) ->
      "The id of the
      #{utils.camel2regular(utils.singularize(options.resourceName))}. This is
      an integer generated by the relational database that is used by the OLD.
      This value can be used to uniquely identify the
      #{utils.camel2regular(utils.singularize(options.resourceName))}."

  uuid =
    eng: (options) ->
      "The UUID (universally unique identifier) of the
      #{utils.camel2regular(utils.singularize(options.resourceName))}. This is
      a unique value generated by the OLD. It is used to create references
      between #{utils.camel2regular(options.resourceName)} and their previous
      versions."

  tooltips =

    fieldDB:

      forms:

        dateElicited: dateElicited

        dateEntered:
          eng: (options) ->
            "This form was entered on #{utils.humanDatetime options.value}"

        dateModified:
          eng: (options) ->
            "This form was last modified on #{utils.humanDatetime options.value}"

        id:
          eng: "A unique identifier for this form (a UUID)."

        comments:
          eng: "Any user with the “commenter” role may add comments to a form.
            The date and time the comment was made and the commenter are
            automatically saved when a comment is created."

          text:
            eng: "The content of the comment."

    old:

      files:
        id: id
        description: description
        datetime_entered: datetimeEntered
        datetime_modified: datetimeModified
        enterer: enterer
        modifier: modifier

        filename:
          eng: 'The name of the file.'

        name:
          eng: 'The name of the file; relevant for externally hosted files or
            subinterval files.'

        lossy_filename:
          eng: 'The name given to the reduced-size copy that was made of this
            file.'

        size:
          eng: (options) ->
            "The size of the file (#{utils.integerWithCommas options.value}
              bytes)"

        MIME_type:
          eng: "The type of the file; technically, this is the MIME
            (Multipurpose Internet Mail Extensions) type or Internet media
            type."

        utterance_type:
          eng: 'If this file represents an utterance, then this value indicates
            whether that utterance is in the object language, the metalanguage,
            or both.'

        speaker:
          eng: 'The speaker of the content encoded in this file, if relevant.'


        elicitor:
          eng: 'The person who elicited/recorded this file, if appropriate.'

        date_elicited:
          eng: (options) ->
            if options.value
              "This file was elicited on #{utils.humanDate options.value}"
            else
              'The date this file was elicited'

        url:
          eng: "The URL where this file’s data are stored."

        password:
          eng: "The password needed to access this file’s data on the external
            server, if needed."

        parent_file:
          eng: "The audio or video file that this (subinterval-referencing)
            file refers to for its file data."

        start:
          eng: "The time in the parent file where this file’s data begins."

        end:
          eng: "The time in the parent file where this file’s data ends."

        dative_file_type:
          eng: "Indicates whether the file’s data are stored on the server,
            are hosted elsewhere, or are a subinterval of another “parent”
            file."

        file_data:
          eng: "Click this button to choose a file for upload."

      morphologicalParsers:
        id: id
        UUID: uuid
        name: name
        description: description
        datetime_entered: datetimeEntered
        datetime_modified: datetimeModified
        enterer: enterer
        modifier: modifier
        generate_succeeded: generateSucceeded
        compile_succeeded: compileSucceeded

        phonology:
          eng: 'The phonology of the morphological parser.'

        morphology:
          eng: 'The morphology of the morphological parser.'

        language_model:
          eng: 'The language model of the morphological parser.'

        generate_message:
          eng: 'The message returned by the OLD after an attempt to generate
            this morphological parser based on the values specified here.'

        generate_attempt:
          eng: 'A unique value (a UUID) created by the OLD after each attempt
            to generate a morphological parser based on the values specified
            here.'

        compile_message: compileMessage
        compile_attempt: compileAttempt

        morphology_rare_delimiter:
          eng: 'A Unicode character used to separate shape, gloss and category
            in the morpheme representations of the morphology of this
            morphological parser.'

      languageModels:
        id: id
        UUID: uuid
        name: name
        description: description
        datetime_entered: datetimeEntered
        datetime_modified: datetimeModified
        enterer: enterer
        modifier: modifier

        corpus:
          eng: 'A corpus that will be used to estimate the language model.'

        vocabulary_morphology:
          eng: 'A morphology that will be used to determine the vocabulary of
            unigrams for the language model.'

        toolkit:
          eng: 'The name of the N-gram language model toolkit to be used to
            create the LM; currently only MITLM is supported.'

        order:
          eng: 'The order of the language model, i.e. "2" for a bigram model or
            "3" for a trigram one.'

        smoothing:
          eng: 'The smoothing algorithm to be used to estimate the language
            model; currently, the only options are the algorithms made
            available by MITLM.'

        categorial:
          eng: 'If set to true, then the elements of the model will be simple
            morpheme categories; if set to false (the default), then the
            elements of the model will be fully specified morphemes, i.e.,
            shape-gloss-category triples.'

        generate_message:
          eng: 'The message returned by the OLD after an attempt to
            estimate/generate a language model based on the specified
            configuration.'

        generate_attempt:
          eng: 'A unique value (a UUID) created by the OLD after each attempt
            to estimate/generate a language model based on the specified
            configuration.'

        perplexity:
          eng: "The perplexity of the language model’s corpus according to the
            language model."

      morphologies:
        id: id
        UUID: uuid
        name: name
        description: description
        datetime_entered: datetimeEntered
        datetime_modified: datetimeModified
        enterer: enterer
        modifier: modifier

        lexicon_corpus:
          eng: 'An OLD corpus from which the lexicon of the morphology will be
            extracted.'

        rules_corpus:
          eng: 'An OLD corpus from which the morphotactic rules of the
            morphology will be extracted.'

        script_type:
          eng: 'The type of FST script that the generated morphology should be
            written in: one of “regex” or “lexc”.'

        extract_morphemes_from_rules_corpus:
          eng: 'If set to true, then morphemes for the morphology will be
            extracted from the rules corpus in addition to also being extracted
            from the lexicon corpus.'

        rules:
          eng: 'Instead of having the system extract morphotactic rules from a
            specified rules corpus, you can specify morphotactic rules in this
            field. Morphotactic rules are strings like “V-Agr”, i.e.,
            sequences of categories and delimiters.'

        rich_upper:
          eng: 'If set to true, then the morphology script will represent
            morphemes on the upper side of the tape as (shape, gloss, category)
            triples; if set to false (the default), then morphemes on the upper
            side of the tape will be represented by their shapes only. See
            Dunham (2014).'

        rich_lower:
          eng: 'If set to true, then the morphology script will represent
            morphemes on the lower side of the tape as (shape, gloss, category)
            triples; if set to false (the default), then morphemes on the lower
            side of the tape will be represented by their shapes only. See
            Dunham (2014).'

        include_unknowns:
          eng: 'If set to true, then morphemes of unknown category will be
            added to lexicon of the morphology.'

        compile_succeeded:
          eng: 'The server will set this to true if a request to compile the
            morphology has completed successfully.'

        compile_message:
          eng: 'Once a compile attempt has terminated, the compile message will
            contain details of the outcome of that attempt.'

        compile_attempt:
          eng: 'After each compile attempt, the server sets the “compile
            attempt” attribute with a new unique (UUID) value.'

        generate_attempt:
          eng: 'After each generate attempt, the server sets the “generate
            attempt” attribute with a new unique (UUID) value.'

        rules_generated:
          eng: 'The morphotactic rules generated by the server during a
            generate attempt.'

      searches:
        name: name
        description: description

        search:
          eng: 'The search expression that defines what forms are to be
            returned and their ordering.'

      phonologies:
        name: name
        description: description
        datetime_entered: datetimeEntered
        datetime_modified: datetimeModified
        enterer: enterer
        modifier: modifier
        UUID: uuid
        id: id
        compile_succeeded: compileSucceeded
        compile_message: compileMessage
        compile_attempt: compileAttempt

        script:
          eng: "The FST script that defines the phonology. An ordered set of
            rewrite rules that conforms to the foma regular
            expression/rewrite rule syntax. See Hulden (2012) and Beesley and
            Karttunen (2003)."

      subcorpora:

        name:
          eng: "A name for the corpus. Each corpus must have a name and
            it must be unique among corpora."

        description:
          eng: "A description of the corpus."

        content:
          eng: "The content of the corpus: a block of text containing
            references to the forms that constitute the content of the
            corpus."

        tags:
          eng: "Tags for categorizing corpora. (These are the same tags that
            are used throughout an OLD application; i.e., the same tag can be
            used to categorize a form and a corpus.)"

        form_search:
          eng: "An OLD form search object which defines the set of forms that
            constitute the corpus."

        id:
          eng: "The id of the corpus. This is an integer generated by the
          relational database that is used by the OLD. This value can be used
          to uniquely identify the corpus."

        UUID:
          eng: "The UUID (universally unique identifier) of the corpus. This
            is a unique value generated by the OLD. It is used to create
            references between corpora and their previous versions."

        enterer:
          eng: "The OLD user who entered/created the corpus. This value is
            specified automatically by the application."

        modifier:
          eng: "The OLD user who made the most recent modification to this
            corpus. This value is specified automatically by the
            application."

        datetime_entered:
          eng: (options) ->
            "This corpus was entered on #{utils.humanDatetime options.value}"

        datetime_modified:
          eng: (options) ->
            "This corpus was last modified on
              #{utils.humanDatetime options.value}"

        files:
          eng: "A list of files associated with this corpus. These are binary
            representations of the corpus in various formats, e.g., NLTK-style
            corpora or PTB-style treebanks. (TODO: verify this!)"

      forms:

        grammaticality:
          eng: "The grammaticality of the form, e.g., grammatical, ungrammatical,
            questionable, infelicitous in a given context. In the OLD,
            grammaticality is a forced-choice field and possible grammaticality
            values are defined on a database-wide setting."

        syntactic_category_string:
          eng: "A sequence of categories and morpheme delimiters (a sequence of
            parts-of-speech) corresponding to the morphological composition of
            the words in the form. If the form is mono-morphemic, then this
            value should be the same as the syntactic category value. The
            syntactic category string value is generated by the OLD based on
            the morpheme break and morpheme gloss values supplied by the user
            and the syntactic category of the morphemes implicit in those
            values. If, for example, a form has a morpheme break value of
            “chien-s” and a morpheme gloss value of “dog-PL”, and if
            the database contains lexical entries for “chien/dog” and
            “s/PL” with categories “N” and “Num”, respectively,
            then the syntactic category string value generated will be
            “N-Num”. Note that the OLD does not allow the syntactic
            category string to be explicitly defined by the user; this is by
            design: the idea is to encourage you to build a lexicon, a
            verbicon, a phrasicon, and a text collection simultaneously. You
            get more accurate syntactic category strings by increasing the
            consistency between your lexicon of morphemes and your lexicon of
            morphologically analyzed phrase-level forms."

        syntactic_category:
          eng: "The syntactic category of the form. Some examples: “N”,
            “S”, “Phi”, “Asp”, “JJ”, etc."

        comments:
          eng: "General-purpose field for notes and commentary about the form."

        speaker_comments:
          eng: "Field specifically for comments about the form made by the
            speaker-consultant."

        elicitation_method:
          eng: "How the form was elicited. Examples: “volunteered”,
            “judged elicitor’s utterance”, “translation task”, etc."

        tags:
          eng: "Tags for categorizing your forms. Note that the tags “foreign
            word” and “restricted” have special meaning in the OLD."

        speaker:
          eng: "The speaker (consultant) who produced or judged the form."

        elicitor:
          eng: "The linguistic fieldworker who elicited the form with the help
            of the consultant."

        enterer:
          eng: "The OLD user who entered/created the form. This value is
            specified automatically by the application."

        modifier:
          eng: "The OLD user who made the most recent modification to this
            form. This value is specified automatically by the application."

        verifier:
          eng: "The OLD user who has verified the reliability/accuracy of
            this form."

        source:
          eng: "The textual source (e.g., research paper, text collection, book
            of learning materials) from which the form was drawn, if applicable.
            Note that the OLD uses the BibTeX reference format for storing
            source information."

        files:
          eng: "The names of any files (e.g., audio, video, image or text
            files) that are associated to this form."

        collections:
          eng: "The titles of any OLD collections (e.g., papers, elicitation
            records, pedagogical materials) that this form is referenced in."

        break_gloss_category:
          eng: "The break/gloss/category value is generated by the
            OLD based on the morpheme break and morpheme gloss values and the
            (also auto-generated) syntactic category string value. The
            break/gloss/category value is a serialization of these three values. A
            form with “chien-s” as morpheme break, “dog-PL” as morpheme
            gloss and “N-Num” as category string will have
            “chien|dog|N-s|PL|Num” as its break/gloss/category value. This
            value is useful for search since it allows one to search through forms
            according to exactly specified morphemes."

        date_elicited: dateElicited

        datetime_entered:
          eng: (options) ->
            "This form was entered on #{utils.humanDatetime options.value}"

        datetime_modified:
          eng: (options) ->
            "This form was last modified on #{utils.humanDatetime options.value}"

        syntax:
          eng: "A syntactic phrase structure representation in some kind of
            string-based format. The OLD assumes that this will be a tree in
            bracket notation using Penn Treebank conventions."

        semantics:
          eng: "A semantic representation of the meaning of the form in some
            string-based format."

        status:
          eng: "The status of the form. This is used to indicate whether the form
          represents tested/verified data or whether it is a fieldworker-crafted form
          that requires testing. The OLD only allows two values for status:
          “tested” and “requires testing”."

        UUID:
          eng: "The UUID (universally unique identifier) of the form. This is a
            unique value generated by the OLD. It is used to create references
            between forms and their previous versions."

        id:
          eng: "The id of the form. This is an integer generated by the
          relational database that is used by the OLD. This value can be used
          to uniquely identify the form."

        narrow_phonetic_transcription:
          eng: "A narrow phonetic transcription, probably in IPA."

        phonetic_transcription:
          eng: "A phonetic transcription, probably in IPA."

        transcription:
          eng: "A transcription, probably orthographic."

        morpheme_break:
          eng: "A sequence of morpheme shapes and delimiters. The OLD assumes
            phonemic shapes (e.g., “in-perfect”), but phonetic (i.e.,
            allomorphic, e.g., “im-perfect”) ones are ok."

        morpheme_gloss:
          eng: "A sequence of morpheme glosses and delimiters, isomorphic to
          the morpheme break sequence, e.g., “NEG-parfait”."

        translations:
          eng: "Translations for the form. The OLD interface and data structure
            allow for any number of translations. Each translation may have its
            own grammaticality/acceptibility specification. Thus a translation that
            is ungrammatical in the metalanguage may be marked with “*” and one
            which is grammatical in the metalanguage but which is incongruous with
            the object language form may have an acceptibility value of “#”."

          transcription:
            eng: "A transcription of a possible translation of this form (in
              the metalanguage, the language of analysis)."

          # Note: this should be changed to "appropriateness" in the OLD.
          grammaticality:
            eng: "The appropriateness of this translation for this form."

  # This is the anonymous function that we return. It returns a second function
  # which returns the tooltip string when called. You use "dot notation" to get
  # the tooltip, e.g., `tooltips('old.forms.syntactic_category')()`.
  (namespace) ->
    parts = namespace.split '.'
    current = tooltips
    for part, index in parts
      if current[part]
        current = current[part]
      else
        current = {}
        break

    (options) ->
      language = options?.language or 'eng'
      if language of current
        tooltip = current[language]
      else if 'eng' of current
        tooltip = current.eng
      else
        tooltip = 'No tooltip.'
      if utils.type(tooltip) is 'function'
        tooltip options
      else
        tooltip

