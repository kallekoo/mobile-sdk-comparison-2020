module Main exposing (Game, Model, Msg(..), decodeGame, init, main, subscriptions, update, view)

import Browser
import Browser.Dom
import Browser.Navigation as Nav
import Element exposing (Attr, Attribute, Color, Column, Decoration, Device, Element, FocusStyle, IndexedColumn, Length, Option, alignLeft, alignTop, centerX, centerY, clip, column, el, fill, fillPortion, height, image, maximum, minimum, moveDown, moveLeft, none, paddingEach, paddingXY, paragraph, px, rgba, rgba255, row, shrink, spacingXY, text, width, wrappedRow)
import Element.Background as BG
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Region as Region
import Html
import Html.Attributes as Attributes
import Http
import Json.Decode
import Json.Decode.Pipeline
import RemoteData exposing (RemoteData(..), WebData)
import Task
import Url
import Url.Parser exposing ((</>), Parser, oneOf, s, string, top)



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , viewport : Maybe Browser.Dom.Viewport
    , games : WebData (List Game)
    , selectedGameDetails : WebData GameDetails
    }


type alias Game =
    { name : String
    , id : String
    , rank : Int
    , thumbnailUrl : String
    , yearPublished : String
    }


type alias GameDetails =
    { name : String
    , id : String
    , thumbnailUrl : String
    , imageUrl : String
    , description : String
    , yearPublished : String
    , categories : List Link
    , mechanisms : List Link
    , designers : List Link
    , artists : List Link
    , expansions : List Link
    , families : List Link
    , implementations : List Link
    , publishers : List Link
    , playersMin : Int
    , playersMax : Int
    , playersBest : Int
    , playingTime : Int
    , playingTimeMin : Int
    , playingTimeMax : Int
    }


type alias Link =
    { name : String
    , id : String
    }


type Route
    = ListRoute
    | GameDetailsRoute String


routeParser : Parser (Route -> a) a
routeParser =
    oneOf
        [ Url.Parser.map ListRoute top
        , Url.Parser.map GameDetailsRoute (s "game" </> string)
        ]


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( Model key url Nothing RemoteData.Loading RemoteData.NotAsked
    , Cmd.batch
        [ getGames
        , Task.perform GotViewport Browser.Dom.getViewport
        ]
    )



-- UPDATE


type Msg
    = GotGames (WebData (List Game))
    | GotGameDetails (WebData GameDetails)
    | TappedGame Game
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotViewport Browser.Dom.Viewport


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotGames games ->
            ( { model | games = games }, Cmd.none )

        GotGameDetails wd ->
            ( { model | selectedGameDetails = wd }, Cmd.none )

        TappedGame g ->
            ( { model
                | selectedGameDetails = RemoteData.Loading
              }
            , Cmd.batch [ Nav.pushUrl model.key ("/game/" ++ g.id), getGameDetails g.id ]
            )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            case Url.Parser.parse routeParser url of
                Just a ->
                    case a of
                        ListRoute ->
                            ( { model
                                | url = url
                                , selectedGameDetails = RemoteData.NotAsked
                              }
                            , Cmd.none
                            )

                        GameDetailsRoute gd ->
                            ( model, getGameDetails gd )

                Nothing ->
                    ( model, Cmd.none )

        GotViewport viewport ->
            ( { model | viewport = Just viewport }, Cmd.none )


baseUrl =
    "http://localhost:38651/api"


getGames : Cmd Msg
getGames =
    Http.get
        { url = baseUrl ++ "/the-hotness"
        , expect = Http.expectJson (RemoteData.fromResult >> GotGames) decodeHotness
        }


getGameDetails : String -> Cmd Msg
getGameDetails gameId =
    Http.get
        { url = baseUrl ++ "/games/" ++ gameId ++ "/details"
        , expect = Http.expectJson (RemoteData.fromResult >> GotGameDetails) decodeGameDetails
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        p =
            case model.selectedGameDetails of
                RemoteData.NotAsked ->
                    listPage model.games

                _ ->
                    let
                        viewport =
                            Maybe.withDefault { scene = { width = 0, height = 0 }, viewport = { x = 0, y = 0, width = 0, height = 0 } } model.viewport
                    in
                    detailPage model.selectedGameDetails viewport
    in
    { title = "The Hotness"
    , body = [ Element.layout [ width fill, height fill, centerX ] p ]
    }


colorDebug a =
    rgba 0 100 0 a


htmlImg url maxw maxh =
    let
        mw =
            String.fromInt maxw ++ "px"

        mh =
            String.fromInt maxh ++ "px"
    in
    Html.img
        [ Attributes.style "object-fit" "contain"
        , Attributes.style "max-width" mw
        , Attributes.style "max-height" mh
        , Attributes.style "width" "auto"
        , Attributes.style "height" "auto"
        , Attributes.src url
        ]
        []
        |> Element.html


detailPage : WebData GameDetails -> Browser.Dom.Viewport -> Element Msg
detailPage wgd viewport =
    let
        statusContainer t =
            column [ width fill, height fill ] [ el [ centerY, centerX, Font.center, width shrink ] <| paragraph [] [ text <| t ] ]

        fontBodyAttributes =
            [ Font.regular ]

        twoToneBoxAttributes =
            [ height shrink, width fill, paddingXY 18 5, BG.color (rgba255 230 230 230 1) ]
    in
    case wgd of
        NotAsked ->
            none

        Loading ->
            statusContainer "Loading"

        Failure e ->
            statusContainer <| errorToString e

        Success gd ->
            let
                _ =
                    Debug.log "description" gd.description

                descriptionLinksElement title elems =
                    [ paragraph
                        [ spacingXY 0 4
                        , height shrink
                        , width fill
                        , Font.bold
                        , paddingEach { top = 7, left = 0, bottom = 3, right = 0 }
                        ]
                        [ text title ]
                    ]
                        ++ List.map (\c -> paragraph [ paddingXY 0 3 ] [ text c.name ]) elems
            in
            column
                [ Font.color (rgba255 46 52 54 1)
                , Font.family
                    [ Font.typeface "system-ui"
                    , Font.typeface "-apple-system"
                    , Font.typeface "sans-serif"
                    ]
                , Font.size 16
                , height fill
                , width fill
                , BG.color <|
                    rgba255 255 255 255 1
                ]
                [ column
                    [ centerX
                    , height fill
                    , width fill
                    ]
                    [ row [ width fill, height shrink, BG.color (rgba 0 0 0 1) ]
                        [ column [ centerX, width shrink, height fill ] [ htmlImg gd.imageUrl (floor viewport.viewport.width) 300 ] ]
                    , row
                        [ height (fill |> maximum 80)
                        , width fill
                        , paddingXY 10 14
                        , BG.color (rgba 0 0 0 1)
                        ]
                        [ paragraph
                            [ Font.bold
                            , Font.color (rgba255 255 255 255 1)
                            , Font.size 20
                            , height (shrink |> maximum 60)
                            , width fill
                            , alignLeft
                            , alignTop
                            , paddingXY 8 0
                            , Region.heading 2
                            ]
                            [ text gd.name ]
                        , el
                            [ Font.bold
                            , Font.color (rgba255 246 252 254 0.55)
                            , Font.size 20
                            , alignLeft
                            , alignTop
                            , paddingXY 14 0
                            , height (shrink |> maximum 60)
                            , width shrink
                            , Region.heading 2
                            ]
                            (text gd.yearPublished)
                        ]
                    , row
                        [ height (shrink |> minimum 56)
                        , width fill
                        , BG.color (rgba255 230 230 230 1)
                        ]
                        [ column
                            [ height (shrink |> minimum 56)
                            , width (fillPortion 2)
                            ]
                            []
                        , column
                            [ height (shrink |> minimum 56)
                            , width (fillPortion 20)
                            , Border.color (rgba 0 0 0 0.2)
                            , Border.widthEach { top = 0, left = 0, bottom = 1, right = 1 }
                            ]
                            [ row
                                [ height shrink
                                , width fill
                                ]
                                [ el
                                    [ height shrink
                                    , width shrink
                                    , centerX
                                    , Font.bold
                                    , paddingEach { top = 12, left = 0, bottom = 0, right = 0 }
                                    ]
                                    (text <| String.fromInt gd.playersMin ++ "–" ++ String.fromInt gd.playersMax ++ " Players")
                                ]
                            , row
                                [ height shrink
                                , width fill
                                ]
                                [ el
                                    [ height shrink
                                    , width shrink
                                    , centerX
                                    , paddingEach { top = 4, left = 0, bottom = 0, right = 0 }
                                    , Font.size 13
                                    ]
                                    (text <| "Best: " ++ String.fromInt gd.playersBest)
                                ]
                            ]
                        , column
                            [ height (shrink |> minimum 56)
                            , width (fillPortion 20)
                            , Border.color (rgba 0 0 0 0.2)
                            , Border.widthEach { top = 0, left = 0, bottom = 1, right = 0 }
                            ]
                            [ row
                                [ height shrink
                                , width fill
                                ]
                                [ el
                                    [ height shrink
                                    , width shrink
                                    , centerX
                                    , Font.bold
                                    , paddingEach { top = 12, left = 0, bottom = 0, right = 0 }
                                    ]
                                    (text <| String.fromInt gd.playingTimeMin ++ "–" ++ String.fromInt gd.playingTimeMax ++ " Min")
                                ]
                            , row
                                [ height shrink
                                , width fill
                                ]
                                [ el
                                    [ height shrink
                                    , width shrink
                                    , centerX
                                    , paddingEach { top = 4, left = 0, bottom = 0, right = 0 }
                                    , Font.size 13
                                    ]
                                    (text "Playing Time")
                                ]
                            ]
                        , column
                            [ height (shrink |> minimum 56)
                            , width (fillPortion 2)
                            ]
                            []
                        ]
                    , row
                        (twoToneBoxAttributes ++ [ paddingEach { top = 18, left = 18, bottom = 5, right = 18 } ])
                        [ column [ width shrink, height fill, paddingEach { top = 0, left = 0, bottom = 0, right = 4 } ]
                            [ paragraph
                                [ spacingXY 0 4
                                , height shrink
                                , width fill
                                , Font.bold
                                ]
                                [ text "Designer:" ]
                            ]
                        , column [ width fill, height fill ]
                            [ paragraph [] [ el ([] ++ fontBodyAttributes) (text <| String.join ", " (List.map (\l -> l.name) gd.designers)) ]
                            ]
                        ]
                    , row
                        twoToneBoxAttributes
                        [ column [ width shrink, height fill, paddingEach { top = 0, left = 0, bottom = 0, right = 4 } ]
                            [ paragraph
                                [ spacingXY 0 4
                                , height shrink
                                , width fill
                                , Font.bold
                                ]
                                [ text "Artist:" ]
                            ]
                        , column [ width fill, height fill ]
                            [ paragraph [] [ el ([] ++ fontBodyAttributes) (text <| String.join ", " (List.map (\l -> l.name) gd.artists)) ]
                            ]
                        ]
                    , row
                        (twoToneBoxAttributes ++ [ paddingEach { top = 5, left = 18, bottom = 12, right = 18 } ])
                        [ column [ width shrink, height fill, paddingEach { top = 0, left = 0, bottom = 0, right = 4 } ]
                            [ paragraph
                                [ spacingXY 0 4
                                , height shrink
                                , width fill
                                , Font.bold
                                ]
                                [ text "Publisher:" ]
                            ]
                        , column [ width fill, height fill ]
                            [ paragraph [] [ el ([] ++ fontBodyAttributes) (text <| String.join ", " (List.map (\l -> l.name) gd.publishers)) ]
                            ]
                        ]
                    , row
                        [ width fill, height shrink, BG.color <| rgba255 255 255 255 1 ]
                        [ column [ height shrink, width (fillPortion 2) ] []
                        , column [ height shrink, width (fillPortion 40) ]
                            [ row
                                [ height shrink
                                , width fill
                                ]
                                [ paragraph
                                    [ Font.bold
                                    , Font.color (rgba255 46 52 54 1)
                                    , Font.size 20
                                    , height shrink
                                    , width fill
                                    , Region.heading 2
                                    , paddingEach { top = 22, left = 0, bottom = 8, right = 0 }
                                    ]
                                    [ text "Description" ]
                                ]
                            , row
                                [ width fill
                                , height (px 1)
                                , Border.color (rgba 0 0 0 0.2)
                                , Border.widthEach { top = 1, left = 0, bottom = 0, right = 0 }
                                , paddingEach { top = 6, left = 0, bottom = 0, right = 0 }
                                ]
                                []
                            , row
                                [ height shrink
                                , width fill
                                ]
                                [ column
                                    [ height shrink
                                    , width fill
                                    , BG.color (rgba255 230 230 230 1)
                                    , paddingEach { top = 6, left = 6, bottom = 6, right = 6 }
                                    ]
                                    (descriptionLinksElement "Category" gd.categories
                                        ++ descriptionLinksElement "Mechanisms" gd.mechanisms
                                        ++ descriptionLinksElement "Family" gd.families
                                    )
                                ]
                            , row
                                [ height shrink
                                , width fill
                                , paddingEach { top = 0, left = 0, bottom = 50, right = 0 }
                                ]
                                [ column [ height shrink, width fill ]
                                    (List.map
                                        (\s ->
                                            paragraph
                                                [ spacingXY 0 4
                                                , height shrink
                                                , width fill
                                                , paddingEach { top = 26, left = 0, bottom = 0, right = 0 }
                                                ]
                                                [ text s ]
                                        )
                                        (String.split "\n" gd.description |> List.filter (\s -> s /= ""))
                                    )
                                ]
                            ]
                        , column [ height shrink, width (fillPortion 2) ] []
                        ]
                    ]
                ]


listPage : WebData (List Game) -> Element Msg
listPage games =
    column
        [ width fill
        , height fill
        ]
        [ el
            ([ paddingXY 16 16
             , width fill
             ]
                ++ fontWithSize 16
                ++ [ Font.center
                   , Font.family
                        [ Font.typeface "Helvetica"
                        , Font.sansSerif
                        ]
                   , Font.bold
                   , Font.alignLeft
                   ]
            )
            (text "The Hotness")
        , gameListView games
        ]


gameListView : WebData (List Game) -> Element Msg
gameListView wlg =
    let
        container =
            column
                [ paddingXY 16 0
                , width fill
                , height fill
                ]
    in
    case wlg of
        Success games ->
            container (List.indexedMap (\i -> \g -> gameCell g (i == List.length games - 1)) games)

        Failure e ->
            container [ el [] (text "Failure") ]

        Loading ->
            container [ el [] (text "Loading") ]

        NotAsked ->
            container [ el [] (text "Kissat koiria sflsfalöfsakflö") ]


gameCell : Game -> Bool -> Element Msg
gameCell g isLast =
    let
        cellH =
            46

        dividerH =
            1

        contentH =
            cellH - dividerH * 2

        dividerTop =
            row [ width fill, height (px 1), BG.color (rgba 0 0 0 0.2) ] []

        dividerBottom =
            if isLast then
                row [ width fill, height (px 1), BG.color (rgba 0 0 0 0.2) ] []

            else
                Element.none
    in
    wrappedRow [ width fill, height (pt cellH), Events.onMouseUp (TappedGame g) ]
        [ column [ width fill, height (pt cellH) ]
            [ row [ width fill, height (px dividerH) ]
                [ dividerTop ]
            , row [ width fill, height (pt contentH) ]
                [ column
                    [ width (fillPortion 2), height (pt contentH), Font.center, clip ]
                    [ image [ centerX, centerY, width (pt <| contentH - 4), height (pt <| contentH - 4), moveLeft 3, moveDown 2, Border.width 0, Border.rounded (siz 4), clip ]
                        { src = g.thumbnailUrl, description = "Logo of " ++ g.name }
                    ]
                , column [ width (fillPortion 5), height (pt contentH) ]
                    [ el [ centerY ] <|
                        column [ paddingXY 10 0 ]
                            [ row (fontWithSize 9 ++ [ Font.alignLeft, width shrink, height shrink ])
                                [ paragraph []
                                    [ text g.name ]
                                ]
                            , row (fontWithSize 6 ++ [ Font.alignLeft, Font.color <| rgba 0 0 0 0.4, width shrink, height shrink, paddingEach { top = 2, left = 0, bottom = 0, right = 0 } ])
                                [ text g.yearPublished ]
                            ]
                    ]
                , column [ width (fillPortion 1), height (pt contentH) ]
                    [ text "" ]
                ]
            , row [ width fill, height (pt contentH) ]
                [ dividerBottom ]
            ]
        ]


fontWithSize : Int -> List (Attribute Msg)
fontWithSize n =
    [ Font.family
        [ Font.typeface "Helvetica"
        , Font.sansSerif
        ]
    , Font.size <| siz n
    ]


siz n =
    n * 2


pt : Int -> Length
pt n =
    px (siz n)



-- Encoding


decodeHotness : Json.Decode.Decoder (List Game)
decodeHotness =
    Json.Decode.field "items" (Json.Decode.list decodeGame)


decodeGame : Json.Decode.Decoder Game
decodeGame =
    Json.Decode.succeed Game
        |> Json.Decode.Pipeline.required "name" Json.Decode.string
        |> Json.Decode.Pipeline.required "id" Json.Decode.string
        |> Json.Decode.Pipeline.required "rank" Json.Decode.int
        |> Json.Decode.Pipeline.required "thumbnailUrl" Json.Decode.string
        |> Json.Decode.Pipeline.required "yearPublished" Json.Decode.string


decodeGameDetails : Json.Decode.Decoder GameDetails
decodeGameDetails =
    Json.Decode.succeed GameDetails
        |> Json.Decode.Pipeline.required "name" Json.Decode.string
        |> Json.Decode.Pipeline.required "id" Json.Decode.string
        |> Json.Decode.Pipeline.required "thumbnailUrl" Json.Decode.string
        |> Json.Decode.Pipeline.required "imageUrl" Json.Decode.string
        |> Json.Decode.Pipeline.required "description" Json.Decode.string
        |> Json.Decode.Pipeline.required "yearPublished" Json.Decode.string
        |> Json.Decode.Pipeline.required "categories" decodeLinkList
        |> Json.Decode.Pipeline.required "mechanisms" decodeLinkList
        |> Json.Decode.Pipeline.required "designers" decodeLinkList
        |> Json.Decode.Pipeline.required "artists" decodeLinkList
        |> Json.Decode.Pipeline.required "expansions" decodeLinkList
        |> Json.Decode.Pipeline.required "families" decodeLinkList
        |> Json.Decode.Pipeline.required "implementations" decodeLinkList
        |> Json.Decode.Pipeline.required "publishers" decodeLinkList
        |> Json.Decode.Pipeline.required "playersMin" Json.Decode.int
        |> Json.Decode.Pipeline.required "playersMax" Json.Decode.int
        |> Json.Decode.Pipeline.required "playersBest" Json.Decode.int
        |> Json.Decode.Pipeline.required "playingTime" Json.Decode.int
        |> Json.Decode.Pipeline.required "playingTimeMin" Json.Decode.int
        |> Json.Decode.Pipeline.required "playingTimeMax" Json.Decode.int


decodeLinkList : Json.Decode.Decoder (List Link)
decodeLinkList =
    Json.Decode.list
        (Json.Decode.succeed Link
            |> Json.Decode.Pipeline.required "name" Json.Decode.string
            |> Json.Decode.Pipeline.required "id" Json.Decode.string
        )



-- UTILS


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "The URL " ++ url ++ " was invalid"

        Http.Timeout ->
            "Unable to reach the server, try again"

        Http.NetworkError ->
            "Unable to reach the server, check your network connection"

        Http.BadStatus 500 ->
            "The server had a problem, try again later"

        Http.BadStatus 400 ->
            "Verify your information and try again"

        Http.BadStatus _ ->
            "Unknown error"

        Http.BadBody errorMessage ->
            errorMessage
