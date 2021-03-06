// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of game;

// Note: Proto and Poker are "fake" games intended to demonstrate what we can do.
// Proto is just a drag cards around "game".
enum GameType { proto, hearts, poker, solitaire }

Map<GameType, String> _gameTypeMap = <GameType, String>{
  GameType.proto: "Proto",
  GameType.hearts: "Hearts",
  GameType.poker: "Poker",
  GameType.solitaire: "Solitaire",
};
String gameTypeToString(GameType t) {
  return _gameTypeMap[t];
}

GameType stringToGameType(String t) {
  GameType gt;
  _gameTypeMap.forEach((GameType type, String name) {
    if (name == t) {
      gt = type;
    }
  });
  return gt;
}

// You should share information like this if you want to setup a game for someone else.
class GameStartData {
  String type;
  int playerNumber;
  int gameID;
  int ownerID;

  GameStartData(this.type, this.playerNumber, this.gameID, this.ownerID);

  GameStartData.fromJSONString(String json) {
    var data = JSON.decode(json);
    type = data["type"];
    playerNumber = data["playerNumber"];
    gameID = data["gameID"];
    ownerID = data["ownerID"];
  }

  String toJSONString() {
    return JSON.encode({
      "type": type,
      "playerNumber": playerNumber,
      "gameID": gameID,
      "ownerID": ownerID
    });
  }

  GameType get gameType => stringToGameType(type);

  @override
  bool operator ==(Object other) {
    if (other is! GameStartData) {
      return false;
    }
    GameStartData gsd = other;
    return gsd.type == type &&
        gsd.playerNumber == playerNumber &&
        gsd.gameID == gameID &&
        gsd.ownerID == ownerID;
  }

  @override
  int get hashCode =>
      23 * type.hashCode +
      37 * playerNumber.hashCode +
      41 * gameID.hashCode +
      43 * ownerID.hashCode;
}

// GameArrangeData details what a game needs before beginning.
class GameArrangeData {
  final bool needsArrangement;
  final Set<int> requiredPlayerNumbers;
  GameArrangeData(this.needsArrangement, this.requiredPlayerNumbers);
  bool canStart(Iterable<int> actualPlayerNumbers) {
    // None of the required player numbers can be missing from the actual ones.
    return !needsArrangement ||
        !requiredPlayerNumbers.any((int i) {
          return !actualPlayerNumbers.contains(i);
        });
  }
}

typedef void VoidCallback();

/// A game consists of multiple decks and tracks a single deck of cards.
/// It also handles events; when cards are dragged to and from decks.
abstract class Game {
  // A super constructor, don't call this unless you're a subclass.
  Game.create(this.gameType, this.gamelog, int numCollections,
      {int gameID, bool isCreator})
      : gameID = gameID ?? new math.Random().nextInt(0x00FFFFFF),
        isCreator = isCreator ?? false {
    print("The gameID is $gameID");
    gamelog.setGame(this);
    for (int i = 0; i < numCollections; i++) {
      cardCollections.add(new List<Card>());
    }
  }

  GameArrangeData get gameArrangeData;
  final GameType gameType;
  String get gameTypeName; // abstract
  bool
      isCreator; // True if this user created the game. Behavior can vary based on this flag, so it can make sense to defer setting it.

  final List<List<Card>> cardCollections = new List<List<Card>>();
  final List<Card> deck = new List<Card>.from(Card.all);
  final int gameID;

  final GameLog gamelog;

  /*int _playerNumber;
  int get playerNumber => _playerNumber;
  // Some subclasses may wish to override this setter to do extra work.
  void set playerNumber(int other) {
    _playerNumber = other;
  }*/
  int playerNumber;

  bool debugMode = false;
  String debugString;

  VoidCallback
      updateCallback; // Used to inform components of when a change has occurred. This is especially important when something non-UI related changes what should be drawn.

  List<Card> deckPeek(int numCards, [int start = 0]) {
    assert(deck.length >= numCards);

    List<Card> cards =
        new List<Card>.from(deck.getRange(start, start + numCards));
    return cards;
  }

  // Which card collection has the card?
  int findCard(Card card) {
    for (int i = 0; i < cardCollections.length; i++) {
      if (cardCollections[i].contains(card)) {
        return i;
      }
    }
    return -1;
  }

  void resetCards() {
    for (int i = 0; i < cardCollections.length; i++) {
      cardCollections[i].clear();
    }
    deck.clear();
    deck.addAll(Card.all);
  }

  // UNIMPLEMENTED
  void move(Card card, List<Card> dest);
  void triggerEvents();
  void startGameSignal();
}
