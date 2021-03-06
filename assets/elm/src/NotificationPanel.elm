module NotificationPanel exposing
    ( NotificationPanel
    , init, setup, catchUp, hasUndismissed, notificationCreated, refresh
    , Msg(..), update
    , view
    )

{-| The notification panel.


# Model

@docs NotificationPanel


# API

@docs init, setup, catchUp, hasUndismissed, notificationCreated, refresh


# Update

@docs Msg, update


# View

@docs view

-}

import Actor exposing (Actor)
import Avatar
import Browser.Navigation as Nav
import Connection exposing (Connection)
import Globals exposing (Globals)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Icons
import Id exposing (Id)
import Mutation.DismissNotification as DismissNotification
import Mutation.DismissNotifications as DismissNotifications
import Notification exposing (State(..))
import NotificationSet exposing (NotificationSet)
import NotificationStateFilter exposing (NotificationStateFilter)
import Post exposing (Post)
import PostReaction exposing (PostReaction)
import Query.Notifications
import RenderedHtml
import Reply exposing (Reply)
import ReplyReaction exposing (ReplyReaction)
import Repo exposing (Repo)
import ResolvedAuthor exposing (ResolvedAuthor)
import ResolvedNotification exposing (Event(..), ResolvedNotification)
import ResolvedPost exposing (ResolvedPost)
import ResolvedReply exposing (ResolvedReply)
import Route
import Session exposing (Session)
import SpaceUser exposing (SpaceUser)
import Task exposing (Task)
import Time exposing (Posix)
import TimeWithZone exposing (TimeWithZone)
import View.Helpers exposing (viewIf)



-- MODEL


type alias NotificationPanel =
    { undismissed : NotificationSet
    , dismissed : NotificationSet
    , currentTab : Notification.State
    }



-- API


init : NotificationPanel
init =
    NotificationPanel
        NotificationSet.empty
        NotificationSet.empty
        Notification.Undismissed


setup : Globals -> NotificationPanel -> Cmd Msg
setup globals model =
    Cmd.batch
        [ globals.session
            |> Query.Notifications.request (Query.Notifications.variables NotificationStateFilter.Undismissed 50 Nothing)
            |> Task.attempt UndismissedFetched
        , globals.session
            |> Query.Notifications.request (Query.Notifications.variables NotificationStateFilter.Dismissed 50 Nothing)
            |> Task.attempt DismissedFetched
        ]


catchUp : Globals -> Posix -> NotificationPanel -> Cmd Msg
catchUp globals lastContactAt model =
    globals.session
        |> Query.Notifications.request (Query.Notifications.catchUpVariables 1000 lastContactAt)
        |> Task.attempt CatchUpReceived


hasUndismissed : NotificationPanel -> Bool
hasUndismissed model =
    not (NotificationSet.isEmpty model.undismissed) || NotificationSet.hasMore model.undismissed


notificationCreated : ResolvedNotification -> NotificationPanel -> NotificationPanel
notificationCreated resolvedNotification model =
    let
        newId =
            resolvedNotification
                |> .notification
                |> Notification.id
    in
    case Notification.state resolvedNotification.notification of
        Notification.Undismissed ->
            { model | undismissed = NotificationSet.add newId model.undismissed }

        Notification.Dismissed ->
            { model | dismissed = NotificationSet.add newId model.dismissed }


refresh : Repo -> NotificationPanel -> NotificationPanel
refresh repo model =
    let
        newlyDismissedIds =
            repo
                |> Repo.getNotifications (NotificationSet.toList model.undismissed)
                |> List.filter (Notification.withState Notification.Dismissed)
                |> List.map Notification.id

        newUndismissed =
            model.undismissed
                |> NotificationSet.removeMany newlyDismissedIds

        newDismissed =
            model.dismissed
                |> NotificationSet.addMany newlyDismissedIds
    in
    { model | undismissed = newUndismissed, dismissed = newDismissed }



-- UPDATE


type Msg
    = NoOp
    | TabChanged Notification.State
    | InternalLinkClicked String
    | CloseClicked
    | MoreUndismissedRequested
    | MoreDismissedRequested
    | UndismissedFetched (Result Session.Error ( Session, Query.Notifications.Response ))
    | DismissedFetched (Result Session.Error ( Session, Query.Notifications.Response ))
    | CatchUpReceived (Result Session.Error ( Session, Query.Notifications.Response ))
    | DismissAllClicked
    | DismissClicked Id
    | NotificationDismissed (Result Session.Error ( Session, DismissNotification.Response ))
    | NotificationsDismissed (Result Session.Error ( Session, DismissNotifications.Response ))


update : Msg -> Globals -> NotificationPanel -> ( ( NotificationPanel, Cmd Msg ), Globals )
update msg globals model =
    case msg of
        NoOp ->
            ( ( model, Cmd.none ), globals )

        TabChanged newTab ->
            ( ( { model | currentTab = newTab }, Cmd.none ), globals )

        InternalLinkClicked pathname ->
            ( ( model, Nav.pushUrl globals.navKey pathname ), globals )

        CloseClicked ->
            ( ( model, Cmd.none ), { globals | showNotifications = False } )

        MoreUndismissedRequested ->
            let
                cursor =
                    NotificationSet.firstOccurredAt globals.repo model.undismissed

                cmd =
                    globals.session
                        |> Query.Notifications.request (Query.Notifications.variables NotificationStateFilter.Undismissed 50 cursor)
                        |> Task.attempt UndismissedFetched
            in
            ( ( model, cmd ), globals )

        MoreDismissedRequested ->
            let
                cursor =
                    NotificationSet.firstOccurredAt globals.repo model.dismissed

                cmd =
                    globals.session
                        |> Query.Notifications.request (Query.Notifications.variables NotificationStateFilter.Dismissed 50 cursor)
                        |> Task.attempt DismissedFetched
            in
            ( ( model, cmd ), globals )

        UndismissedFetched (Ok ( newSession, resp )) ->
            let
                newRepo =
                    Repo.union resp.repo globals.repo

                newIds =
                    resp.resolvedNotifications
                        |> Connection.toList
                        |> List.map (Notification.id << .notification)

                hasNextPage =
                    Connection.hasNextPage resp.resolvedNotifications

                newUndismissed =
                    model.undismissed
                        |> NotificationSet.addMany newIds
                        |> NotificationSet.setLoaded
                        |> NotificationSet.setHasMore hasNextPage
            in
            ( ( { model | undismissed = newUndismissed }, Cmd.none )
            , { globals | repo = newRepo, session = newSession }
            )

        UndismissedFetched (Err Session.Expired) ->
            ( ( model, Route.toLogin ), globals )

        UndismissedFetched _ ->
            ( ( model, Cmd.none ), globals )

        DismissedFetched (Ok ( newSession, resp )) ->
            let
                newRepo =
                    Repo.union resp.repo globals.repo

                newIds =
                    resp.resolvedNotifications
                        |> Connection.toList
                        |> List.map (Notification.id << .notification)

                hasNextPage =
                    Connection.hasNextPage resp.resolvedNotifications

                newDismissed =
                    model.dismissed
                        |> NotificationSet.addMany newIds
                        |> NotificationSet.setLoaded
                        |> NotificationSet.setHasMore hasNextPage
            in
            ( ( { model | dismissed = newDismissed }, Cmd.none )
            , { globals | repo = newRepo, session = newSession }
            )

        DismissedFetched (Err Session.Expired) ->
            ( ( model, Route.toLogin ), globals )

        DismissedFetched _ ->
            ( ( model, Cmd.none ), globals )

        CatchUpReceived (Ok ( newSession, resp )) ->
            let
                newRepo =
                    Repo.union resp.repo globals.repo

                newIds =
                    resp.resolvedNotifications
                        |> Connection.toList
                        |> List.map (Notification.id << .notification)

                newUndismissed =
                    model.undismissed
                        |> NotificationSet.addMany newIds

                newModel =
                    { model | undismissed = newUndismissed }
                        |> refresh newRepo
            in
            ( ( newModel, Cmd.none )
            , { globals | repo = newRepo, session = newSession }
            )

        CatchUpReceived (Err Session.Expired) ->
            ( ( model, Route.toLogin ), globals )

        CatchUpReceived _ ->
            ( ( model, Cmd.none ), globals )

        DismissAllClicked ->
            let
                cmd =
                    globals.session
                        |> DismissNotifications.request (DismissNotifications.variables Nothing)
                        |> Task.attempt NotificationsDismissed
            in
            ( ( model, cmd ), globals )

        DismissClicked id ->
            let
                cmd =
                    globals.session
                        |> DismissNotification.request (DismissNotification.variables id)
                        |> Task.attempt NotificationDismissed
            in
            ( ( model, cmd ), globals )

        NotificationDismissed (Ok ( newSession, DismissNotification.Success resolvedNotification )) ->
            let
                newRepo =
                    ResolvedNotification.addToRepo resolvedNotification globals.repo

                newModel =
                    refresh newRepo model
            in
            ( ( newModel, Cmd.none )
            , { globals | repo = newRepo, session = newSession }
            )

        NotificationDismissed (Err Session.Expired) ->
            ( ( model, Route.toLogin ), globals )

        NotificationDismissed _ ->
            ( ( model, Cmd.none ), globals )

        NotificationsDismissed (Ok ( newSession, DismissNotifications.Success maybeTopic )) ->
            let
                newRepo =
                    Repo.dismissNotifications maybeTopic globals.repo

                newModel =
                    case maybeTopic of
                        Nothing ->
                            { model
                                | undismissed = NotificationSet.setHasMore False model.undismissed
                                , dismissed = NotificationSet.setHasMore True model.dismissed
                            }

                        Just _ ->
                            model
            in
            ( ( newModel, Cmd.none )
            , { globals | repo = newRepo, session = newSession }
            )

        NotificationsDismissed (Err Session.Expired) ->
            ( ( model, Route.toLogin ), globals )

        NotificationsDismissed _ ->
            ( ( model, Cmd.none ), globals )



-- VIEW


type alias CardConfig =
    { id : Id
    , topic : String
    , url : String
    , icon : Html Msg
    , displayName : Html Msg
    , action : String
    , occurredAt : Posix
    , preview : Html Msg
    , isUndismissed : Bool
    }


view : Globals -> NotificationPanel -> Html Msg
view globals model =
    let
        ( visibleSet, loadMoreMsg ) =
            case model.currentTab of
                Notification.Undismissed ->
                    ( model.undismissed, MoreUndismissedRequested )

                Notification.Dismissed ->
                    ( model.dismissed, MoreDismissedRequested )

        itemViews =
            visibleSet
                |> NotificationSet.resolve globals.repo
                |> List.map (notificationView globals)
    in
    div [ class "fixed font-sans font-antialised w-80 xl:w-88 pin-t pin-r pin-b bg-white shadow-dropdown z-50" ]
        [ div []
            [ div [ class "flex items-center py-2 pl-4 pr-3" ]
                [ h2 [ class "text-lg flex-grow" ] [ text "Notifications" ]
                , button
                    [ classList
                        [ ( "flex items-center justify-center px-4 h-9 rounded-full no-outline", True )
                        , ( "text-dusty-blue hover:text-dusty-blue-dark text-md font-bold", True )
                        , ( "bg-transparent hover:bg-grey transition-bg", True )
                        , ( "mr-2", True )
                        ]
                    , onClick DismissAllClicked
                    ]
                    [ text "Dismiss All" ]
                , button
                    [ class "flex items-center justify-center w-9 h-9 rounded-full bg-transparent hover:bg-grey transition-bg"
                    , onClick CloseClicked
                    ]
                    [ Icons.ex ]
                ]
            , div [ class "pt-1 flex items-baseline trans-border-b-grey" ]
                [ button
                    [ classList
                        [ ( "flex-1 -mb-px block text-md py-3 px-4 border-b-3 border-transparent no-underline font-bold text-center leading-normal no-outline", True )
                        , ( "text-dusty-blue-dark", model.currentTab /= Undismissed )
                        , ( "border-blue text-blue", model.currentTab == Undismissed )
                        ]
                    , onClick (TabChanged Undismissed)
                    ]
                    [ text "Unread" ]
                , button
                    [ classList
                        [ ( "flex-1 -mb-px block text-md py-3 px-4 border-b-3 border-transparent no-underline font-bold text-center leading-normal no-outline", True )
                        , ( "text-dusty-blue-dark", model.currentTab /= Dismissed )
                        , ( "border-blue text-blue", model.currentTab == Dismissed )
                        ]
                    , onClick (TabChanged Dismissed)
                    ]
                    [ text "Read" ]
                ]
            ]
        , div [ class "absolute pin overflow-y-auto", style "top" "103px" ]
            [ div [] itemViews
            , viewIf (NotificationSet.isEmpty visibleSet) <|
                div [ class "pt-16 pb-16 font-headline text-center text-lg text-dusty-blue-dark" ]
                    [ text "You're all caught up!" ]
            , viewIf (NotificationSet.hasMore visibleSet) <|
                div [ class "py-8 text-center" ]
                    [ button
                        [ class "btn btn-grey-outline btn-md"
                        , onClick loadMoreMsg
                        ]
                        [ text "Load more..." ]
                    ]
            ]
        ]


notificationView : Globals -> ResolvedNotification -> Html Msg
notificationView globals resolvedNotification =
    let
        notification =
            resolvedNotification.notification

        timestamp =
            View.Helpers.timeTag globals.now
                (TimeWithZone.setPosix (Notification.occurredAt notification) globals.now)
                [ class "block flex-no-grow text-sm text-dusty-blue-dark whitespace-no-wrap" ]

        classes =
            classList
                [ ( "flex text-dusty-blue-darker px-4 py-4 border-b text-left w-full leading-normal no-underline", True )
                , ( "hover:bg-grey-light", not <| Notification.isUndismissed notification )
                , ( "bg-blue-lightest hover:bg-blue-light", Notification.isUndismissed notification )
                ]
    in
    case resolvedNotification.event of
        PostCreated resolvedPost ->
            cardTemplate globals
                { id = Notification.id notification
                , topic = Notification.topic notification
                , url = Post.url resolvedPost.post
                , icon = Icons.postCreated
                , displayName = authorDisplayName resolvedPost.author
                , action = "posted"
                , occurredAt = Notification.occurredAt notification
                , preview = postPreview globals resolvedPost
                , isUndismissed = Notification.isUndismissed notification
                }

        PostClosed resolvedPost actor ->
            cardTemplate globals
                { id = Notification.id notification
                , topic = Notification.topic notification
                , url = Post.url resolvedPost.post
                , icon = Icons.postClosed
                , displayName = actorDisplayName actor
                , action = "resolved a post"
                , occurredAt = Notification.occurredAt notification
                , preview = postPreview globals resolvedPost
                , isUndismissed = Notification.isUndismissed notification
                }

        PostReopened resolvedPost actor ->
            cardTemplate globals
                { id = Notification.id notification
                , topic = Notification.topic notification
                , url = Post.url resolvedPost.post
                , icon = Icons.postClosed
                , displayName = actorDisplayName actor
                , action = "reopened a post"
                , occurredAt = Notification.occurredAt notification
                , preview = postPreview globals resolvedPost
                , isUndismissed = Notification.isUndismissed notification
                }

        ReplyCreated resolvedReply ->
            cardTemplate globals
                { id = Notification.id notification
                , topic = Notification.topic notification
                , url = Reply.url resolvedReply.reply
                , icon = Icons.replyCreated
                , displayName = authorDisplayName resolvedReply.author
                , action = "replied"
                , occurredAt = Notification.occurredAt notification
                , preview = replyPreview globals resolvedReply
                , isUndismissed = Notification.isUndismissed notification
                }

        PostReactionCreated resolvedReaction ->
            cardTemplate globals
                { id = Notification.id notification
                , topic = Notification.topic notification
                , url = Post.url resolvedReaction.resolvedPost.post
                , icon = Icons.reactionCreated
                , displayName = spaceUserDisplayName resolvedReaction.spaceUser
                , action = "reacted with " ++ PostReaction.value resolvedReaction.reaction
                , occurredAt = Notification.occurredAt notification
                , preview = postPreview globals resolvedReaction.resolvedPost
                , isUndismissed = Notification.isUndismissed notification
                }

        ReplyReactionCreated resolvedReaction ->
            cardTemplate globals
                { id = Notification.id notification
                , topic = Notification.topic notification
                , url = Reply.url resolvedReaction.resolvedReply.reply
                , icon = Icons.reactionCreated
                , displayName = spaceUserDisplayName resolvedReaction.spaceUser
                , action = "reacted with " ++ ReplyReaction.value resolvedReaction.reaction
                , occurredAt = Notification.occurredAt notification
                , preview = replyPreview globals resolvedReaction.resolvedReply
                , isUndismissed = Notification.isUndismissed notification
                }



-- PRIVATE


cardTemplate : Globals -> CardConfig -> Html Msg
cardTemplate globals config =
    div
        [ classList
            [ ( "flex text-dusty-blue-darker px-4 py-4 border-b text-left w-full leading-normal no-underline", True )
            , ( "hover:bg-grey-light", not config.isUndismissed )
            , ( "bg-blue-lightest hover:bg-blue-light", config.isUndismissed )
            ]
        ]
        [ div [ class "mr-3 w-6" ] [ config.icon ]
        , a [ href config.url, class "block no-underline flex-grow min-w-0" ]
            [ div [ class "flex items-baseline pt-1/2 pb-4" ]
                [ div [ class "flex-grow mr-1 text-dusty-blue-darker" ]
                    [ config.displayName
                    , span [] [ text (" " ++ config.action) ]
                    ]
                , View.Helpers.timeTag globals.now
                    (TimeWithZone.setPosix config.occurredAt globals.now)
                    [ class "block flex-no-grow text-sm text-dusty-blue-dark whitespace-no-wrap" ]
                ]
            , config.preview
            ]
        , viewIf config.isUndismissed <|
            div [ class "ml-3" ]
                [ button
                    [ class "-mt-px flex items-center justify-center w-7 h-7 rounded-full bg-transparent hover:bg-grey transition-bg"
                    , onClick (DismissClicked config.id)
                    ]
                    [ Icons.exSmall ]
                ]
        ]


authorDisplayName : ResolvedAuthor -> Html Msg
authorDisplayName resolvedAuthor =
    span [ class "font-bold" ]
        [ text <| ResolvedAuthor.displayName resolvedAuthor ]


actorDisplayName : Actor -> Html Msg
actorDisplayName actor =
    span [ class "font-bold" ]
        [ text <| Actor.displayName actor ]


spaceUserDisplayName : SpaceUser -> Html Msg
spaceUserDisplayName spaceUser =
    span [ class "font-bold" ]
        [ text <| SpaceUser.displayName spaceUser ]


postPreview : Globals -> ResolvedPost -> Html Msg
postPreview globals resolvedPost =
    div
        [ classList [ ( "flex text-md relative", True ) ]
        ]
        [ div [ class "flex-no-shrink mr-2 z-10 pt-1" ]
            [ Avatar.fromConfig (ResolvedAuthor.avatarConfig Avatar.Small resolvedPost.author) ]
        , div
            [ classList
                [ ( "min-w-0 leading-normal -ml-6 px-6", True )
                ]
            ]
            [ div [ class "pb-1/2" ]
                [ authorLabel resolvedPost.author
                , View.Helpers.timeTag globals.now
                    (TimeWithZone.setPosix (Post.postedAt resolvedPost.post) globals.now)
                    [ class "mr-3 text-sm text-dusty-blue whitespace-no-wrap" ]
                ]
            , div []
                [ div [ class "markdown pb-1 break-words text-dusty-blue-dark max-h-16 overflow-hidden" ]
                    [ RenderedHtml.node
                        { html = Post.bodyHtml resolvedPost.post
                        , onInternalLinkClicked = InternalLinkClicked
                        }
                    ]

                -- , staticFilesView (Reply.files reply)
                ]

            -- , div [ class "pb-1/2 flex items-start" ] [ postReactionIndicator resolvedPost ]
            ]
        ]


replyPreview : Globals -> ResolvedReply -> Html Msg
replyPreview globals resolvedReply =
    div
        [ classList [ ( "flex text-md relative", True ) ]
        ]
        [ div [ class "flex-no-shrink mr-2 z-10 pt-1" ]
            [ Avatar.fromConfig (ResolvedAuthor.avatarConfig Avatar.Small resolvedReply.author) ]
        , div
            [ classList
                [ ( "min-w-0 leading-normal -ml-6 px-6", True )
                , ( "py-2 bg-grey-light rounded-xl", False )
                ]
            ]
            [ div [ class "pb-1/2" ]
                [ authorLabel resolvedReply.author
                , View.Helpers.timeTag globals.now
                    (TimeWithZone.setPosix (Reply.postedAt resolvedReply.reply) globals.now)
                    [ class "mr-3 text-sm text-dusty-blue whitespace-no-wrap" ]
                ]
            , div []
                [ div [ class "markdown pb-1 break-words text-dusty-blue-dark max-h-16 overflow-hidden" ]
                    [ RenderedHtml.node
                        { html = Reply.bodyHtml resolvedReply.reply
                        , onInternalLinkClicked = InternalLinkClicked
                        }
                    ]

                -- , staticFilesView (Reply.files reply)
                ]

            -- , div [ class "pb-1/2 flex items-start" ] [ replyReactionIndicator resolvedReply ]
            ]
        ]


authorLabel : ResolvedAuthor -> Html Msg
authorLabel author =
    span
        [ class "whitespace-no-wrap"
        ]
        [ span [ class "font-bold text-dusty-blue-dark mr-2" ] [ text <| ResolvedAuthor.displayName author ]
        , span [ class "ml-2 text-dusty-blue hidden" ] [ text <| "@" ++ ResolvedAuthor.handle author ]
        ]
