type connection = {title: string, values: array<string>}
type connections = list<(Group.t, connection)>

@unboxed
type rowId = RowId(int)
let rowKey = (RowId(int)) => Int.toString(int)
type rows = list<(rowId, connection)>

let blankRow: connection = {title: "", values: Belt.Array.make(4, "")}
let blankRows: rows = List.makeBy(4, i => (RowId(i), blankRow))

let getRow = (rows: rows, id: rowId): connection =>
  List.getAssoc(rows, id, Utils.Id.eq)->Option.getExn
let setRow = (rows: rows, id: rowId, row: connection): rows =>
  List.setAssoc(rows, id, row, Utils.Id.eq)

let toConnections = (rows: rows): connections =>
  Group.rainbow->List.zip(rows->List.unzip->Utils.Tuple.snd)

type cardId = CardId(Group.t, int)

type card = {group: Group.t, id: cardId, value: string}
type cards = array<card>

type solution = {group: Group.t, title: string, values: array<string>}
type solved = array<solution>

let makeCards = (rows: connections): cards => {
  List.toArray(rows)->Belt.Array.flatMap(((group, {values})) =>
    values->Belt.Array.mapWithIndex((i, value) => {
      group,
      id: CardId(group, i),
      value: Js.String.trim(value),
    })
  )
}

let cardKey = (CardId(group, i)) => `${Group.name(group)}-${Belt.Int.toString(i)}`
let groupFromId = (CardId(group, _)) => group
let indexFromId = (CardId(_, i)) => i

let cardInGroup = ({group}: card, g) => group == g

let inCanonicalOrder = (cardIds: array<cardId>): array<cardId> => {
  let fillGapsWith = (toFill, fillFrom) => {
    let rec fill = (filled, toFill, fillFrom) => {
      switch (toFill[0], fillFrom[0]) {
      | (Some(nextFill), Some(nextFrom)) => {
          let CardId(_, i) = nextFill
          if Belt.Array.length(filled) == i {
            filled->Belt.Array.concat([nextFill])->fill(toFill->Belt.Array.sliceToEnd(1), fillFrom)
          } else {
            filled->Belt.Array.concat([nextFrom])->fill(toFill, fillFrom->Belt.Array.sliceToEnd(1))
          }
        }
      | _ => Belt.Array.concatMany([filled, toFill, fillFrom])
      }
    }

    fill([], toFill, fillFrom)
  }

  let sortedGroups =
    cardIds
    ->Utils.Array.groupBy(groupFromId)
    ->List.sort(((group1, ids1), (group2, ids2)) =>
      Array.length(ids1) == Array.length(ids2)
        ? Group.index(group1) - Group.index(group2)
        : Array.length(ids2) - Array.length(ids1)
    )
    ->List.map(((group, ids)) => (
      group,
      ids->List.fromArray->List.sort((CardId(_, i1), CardId(_, i2)) => i1 - i2)->List.toArray,
    ))

  switch sortedGroups {
  | list{} => []
  | list{(_, primary), ...groups} =>
    primary->fillGapsWith(groups->List.toArray->Belt.Array.flatMap(Utils.Tuple.snd))
  }
}

let makeSolution = (group: Group.t, {title, values}: connection): solution => {group, title, values}

let findSolution = (guess: array<cardId>, connections: connections) => {
  guess
  ->Utils.Array.matchAllBy(groupFromId)
  ->Option.flatMap(group => {
    connections->List.getAssoc(group, Utils.Id.eq)->Option.map(makeSolution(group, _))
  })
}

let remainingSolutions = (connections: connections, solved: array<solution>): array<solution> =>
  connections
  ->List.toArray
  ->Belt.Array.keepMap(((group, connection)) =>
    solved->Belt.Array.every(({group: g}) => group != g)
      ? Some(makeSolution(group, connection))
      : None
  )

let sampleValues = (): rows =>
  list{
    ("Forms of Transportation We've Taken Together", ["Fly", "Drive", "Cruise", "Train"]),
    ("Countries We've Been To Together", ["US", "DE", "CAN", "ENG"]),
    ("Our Forms of Communication When Remote", ["Playlist", "Text", "Letter", "Zoom"]),
    ("MLB Teams We've Seen Together", ["PHI", "COL", "MIN", "WAS"]),
  }->List.mapWithIndex((i, (title, values)) => (RowId(i), {title, values}))

module Decode = {
  open Funicular.Decode

  type decodeConnectionsError = [jsonParseError | #Base64ParseError | #Not4Connections]
  type decodeIdError = [jsonParseError | #UnknownGroup]

  let cardId: parser<cardId, decodeIdError> = value => {
    let o = value->object_
    let group =
      o->field("g", v =>
        v
        ->string
        ->Result.flatMap(g => g->Group.fromShortName->Utils.Result.fromOption(#UnknownGroup))
      )
    let index = o->field("i", integer)

    rmap((g, i) => CardId(g, i))->v(group)->v(index)
  }

  let cardIds: parser<array<cardId>, decodeIdError> = array(cardId, _)
  let guesses: parser<array<array<cardId>>, decodeIdError> = array(cardIds, _)

  let cards: parser<array<card>, decodeIdError> = array(value => {
    let o = value->object_
    let id = o->field("id", cardId)
    let name = o->field("v", string)

    rmap((id, name) => {group: groupFromId(id), id, value: name})->v(id)->v(name)
  }, _)

  let connections: parser<connections, decodeConnectionsError> = value => {
    value
    ->array(item => {
      let o = item->object_
      let title = o->field("t", string)
      let values = o->field("v", array(string, _))

      rmap((title, values) => {title, values})->v(title)->v(values)
    }, _)
    ->Result.flatMap(connections => {
      if Belt.Array.length(connections) != 4 {
        Error(#Not4Connections)
      } else {
        connections->List.fromArray->List.zip(Group.rainbow, _)->Ok
      }
    })
  }

  let slug: string => result<connections, decodeConnectionsError> = slug => {
    slug
    ->Base64.decode
    ->Utils.Result.fromOption(#Base64ParseError)
    ->Result.flatMap(parse(_, connections))
  }
}

module Encode = {
  open Funicular.Encode

  let cardId = (CardId(group, i)) =>
    object_([("g", group->Group.shortName->string), ("i", integer(i))])
  let cardIds = array(_, cardId)
  let guesses = array(_, cardIds)
  let cards = array(_, ({id, value}) => object_([("id", cardId(id)), ("v", string(value))]))

  let json = (connections: connections) =>
    connections
    ->List.toArray
    ->array(((_, {title, values})) => object_([("t", string(title)), ("v", array(values, string))]))

  let slug = (connections: connections) => {
    connections->json->Js.Json.stringify->Base64.encode(_, true)
  }
}
