require_relative '../../../directory'
require_relative PathFor[:repo_helper]
require_relative PathFor[:textmate_tools]
require_relative PathFor[:sharedPattern]["numeric"]
require_relative PathFor[:sharedPattern]["variable"]
require_relative './tokens.rb'

# 
# Setup grammar
# 
    grammar = Grammar.new(
        name: "Dockerfile",
        scope_name: "source.dockerfile",
        file_types: [
            "dockerfile",
        ],
        version: "",
        information_for_contributors: [
            "This code was auto generated by a much-more-readble ruby file",
            "see https://github.com/jeff-hykin/cpp-textmate-grammar/blob/master",
        ],
    )

#
#
# Contexts
#
#
    grammar[:$initial_context] = [
            :commands,
            :escape,
            :variable,
            :comments,
            :strings,
        ]
#
#
# Patterns
#
#
    # 
    # String
    # 
        grammar[:strings] = [
            :string_single,
            :string_double,
        ]
        grammar[:escape] = Pattern.new(
            match: /\\./,
            tag_as: "constant.character.escaped"
        )
        grammar[:string_single] = PatternRange.new(
            tag_as: "string.quoted.single",
            start_pattern: Pattern.new(
                match: /'/,
                tag_as: "punctuation.definition.string.begin",
            ),
            end_pattern: Pattern.new(
                match: /'/,
                tag_as: "punctuation.definition.string.end",
            ),
            includes: [ :escape, :variable ]
        )
        grammar[:string_double] = PatternRange.new(
            tag_as: "string.quoted.double",
            start_pattern: Pattern.new(
                match: /"/,
                tag_as: "punctuation.definition.string.begin",
            ),
            end_pattern: Pattern.new(
                match: /"/,
                tag_as: "punctuation.definition.string.end",
            ),
            includes: [ :escape, :variable ]
        )
    # 
    # Comment
    # 
        grammar[:comments] = Pattern.new(
            /^\s*+/.then(
                match: /#/,
                tag_as: "comment.line.number-sign punctuation.definition.comment",
            ).then(
                match: /.*$/,
                tag_as: "comment.line.number-sign"
            )
        )
    # 
    # variable
    # 
        grammar[:variable] = Pattern.new(
            Pattern.new(
                match: /\$/,
                tag_as: "punctuation.definition.variable variable.other"
            ).then(
                match: /\w+/,
                tag_as: "variable.other",
            )
        )
    # 
    # Normal Commands 
    # 
        grammar[:commands] = [
            :env_statement,
            :run_statement,
            :from_statement,
            Pattern.new(
                /^\s*+/.maybe(
                    Pattern.new(
                        match: /(?i:ONBUILD)/,
                        tag_as: "keyword.control.onbuild",
                    ).then(/\s++/)
                ).then(
                    match: /(?i:CMD|ENTRYPOINT|ADD|ARG|CMD|COPY|ENTRYPOINT|ENV|EXPOSE|HEALTHCHECK|LABEL|MAINTAINER|RUN|SHELL|STOPSIGNAL|USER|VOLUME|WORKDIR)/,
                    tag_as: "keyword.other.special-method.$match"
                ).then(/\s/)
            )
        ]
    # 
    # FROM
    # 
        # see https://docs.docker.com/engine/reference/builder/
            # syntax=docker/dockerfile
            # syntax=docker/dockerfile:1.0
            # syntax=docker.io/docker/dockerfile:1
            # syntax=docker/dockerfile:1.0.0-experimental
            # syntax=example.com/user/repo:tag@sha256:abcdef...
        grammar[:from_statement] = Pattern.new(
            Pattern.new(
                match: /(?i:FROM)/,
                tag_as: "keyword.other.special-method.from"
            ).then(/\s+/).then(
                match: /[^\s]+/,
                includes: [
                    # tag the image
                    Pattern.new(
                        match: /[^:@]+/,
                        tag_as: "entity.name.image"
                    ),
                    # tag the version
                    Pattern.new(
                        Pattern.new(
                            match: /\:/,
                            tag_as: "punctuation.separator.version constant.numeric.version",
                        ).then(
                            match: /\S++/,
                            tag_as: "constant.numeric.version"
                        )
                    ),
                    # tag the digest
                    Pattern.new(
                        Pattern.new(
                            match: /\@/,
                            tag_as: "punctuation.separator.version constant.constant.language.symbol.digest",
                        ).then(
                            match: /\S++/,
                            tag_as: "constant.constant.language.symbol.digest"
                        )
                    )
                ]
                
            ).maybe(
                /\s+/.then(
                    match: /(?i:AS)/,
                    tag_as: "keyword.other.special-method.as",
                ).then(/\s+/).then(
                    match: /[^\s]++/,
                    tag_as: "entity.name.image.stage",
                )
            )
        )
    
    # 
    # RUN
    #         
        # pull in the entire shell syntax
        grammar[:shell] = JSON.parse(IO.read(PathFor[:jsonSyntax]["shell"]))
        # allow the command call to have CMD or RUN infront of it
        grammar[:shell]["repository"]["command_call"]["begin"] = "(?<=(?:^|;|\\||&|!|\\(|\\{|\\`|RUN|CMD))\\s*+(?!function\\W|function\\$|export\\W|export\\$|select\\W|select\\$|case\\W|case\\$|do\\W|do\\$|done\\W|done\\$|elif\\W|elif\\$|else\\W|else\\$|esac\\W|esac\\$|fi\\W|fi\\$|for\\W|for\\$|if\\W|if\\$|in\\W|in\\$|then\\W|then\\$|until\\W|until\\$|while\\W|while\\$)"
        # tell the shell syntax when it needs to end
        grammar[:shell]["patterns"][0]["end"] = lookBehindFor(/[^\\]\n/)
        
        
        grammar[:run_statement] = PatternRange.new(
            tag_content_as: "meta.command.run",
            start_pattern: Pattern.new(
                Pattern.new(
                    match: variableBounds(/RUN/),
                    tag_as: "keyword.other.special-method",
                # look to make sure the line gets extended at the end with a \
                )
            ),
            # while the line is beging extended with \
            # while: lookAheadFor(/^.+\\$/),
            end_pattern: lookBehindFor(/[^\\]\n/),
            includes: [
                :shell
            ]
        )
    # 
    # ENV
    # 
        grammar[:env_statement] = PatternRange.new(
            tag_content_as: "meta.command.env",
            # ENV myName="John Doe" myDog=Rex\ The\ Dog \
            #     myCat=fluffy
            # ENV myName John Doe
            # ENV myDog Rex The Dog
            # ENV myCat fluffy
            start_pattern: Pattern.new(
                Pattern.new(
                    match: variableBounds(/ENV/),
                    tag_as: "keyword.other.special-method",
                # look to make sure the line gets extended at the end with a \
                )
            ),
            # while the line is beging extended with \
            # while: lookAheadFor(/^.+\\$/),
            end_pattern: lookBehindFor(/[^\\]\n/),
            includes: [
                # this covers:
                #   ENV myName John Doe
                #   ENV myDog Rex The Dog
                #   ENV myCat fluffy
                Pattern.new(
                    lookBehindFor(/ENV/).then(/\s+/).then(
                        match: /\w+/,
                        tag_as: "variable.other.assignment",
                    ).then(/ +/).then(
                        match: /.+/,
                        tag_as: "string.unquoted",
                    )
                ),
                # this covers:
                #    myName=
                Pattern.new(
                    Pattern.new(
                        match: /\w+?/.lookAheadFor(/=/),
                        tag_as: "variable.other.assignment",
                    ).then(
                        match: /\=/,
                        tag_as: "keyword.operator.assignment",
                    )
                ),
                # this covers
                #    myName='thing'
                PatternRange.new(
                    tag_as: "string.quoted.single",
                    start_pattern: lookBehindFor(/=/).then(
                        match: /'/,
                        tag_as: "punctuation.definition.string.begin",
                    ),
                    end_pattern: Pattern.new(
                        match: /'/,
                        tag_as: "punctuation.definition.string.end",
                    ),
                    includes: [ :escape, :variable ]
                ),
                # this covers
                #    myName="thing"
                PatternRange.new(
                    tag_as: "string.quoted.double",
                    start_pattern: lookBehindFor(/=/).then(
                        match: /"/,
                        tag_as: "punctuation.definition.string.begin",
                    ),
                    end_pattern: Pattern.new(
                        match: /"/,
                        tag_as: "punctuation.definition.string.end",
                    ),
                    includes: [ :escape, :variable ]
                ),
                # this covers
                #    myDog=Rex\ The\ Dog
                lookBehindFor(/=/).then(
                    match: /(?:\\\s|[^\s])+/,
                    tag_as: "string.unquoted",
                ),
                # this is for the \ on line continuations
                Pattern.new(
                    match: /\\\n/,
                    tag_as: "constant.character.escape.line-continuation"
                )
            ]
        )
 
# Save
saveGrammar(grammar)