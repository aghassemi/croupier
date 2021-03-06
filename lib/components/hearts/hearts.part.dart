// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

part of game_component;

class HeartsGameComponent extends GameComponent {
  HeartsGameComponent(Croupier croupier, SoundAssets sounds, VoidCallback cb,
      {Key key, double width, double height})
      : super(croupier, sounds, cb, key: key, width: width, height: height);

  @override
  HeartsGame get game {
    return super.game;
  }

  @override
  HeartsGameComponentState createState() => new HeartsGameComponentState();
}

class HeartsGameComponentState extends GameComponentState<HeartsGameComponent> {
  List<logic_card.Card> passingCards1 = new List<logic_card.Card>();
  List<logic_card.Card> passingCards2 = new List<logic_card.Card>();
  List<logic_card.Card> passingCards3 = new List<logic_card.Card>();
  List<logic_card.Card> bufferedPlay = new List<logic_card.Card>();
  bool bufferedPlaying = false;

  HeartsType _lastViewType;
  bool _showSplitView = false;

  @override
  void initState() {
    super.initState();

    // If someone sat at the table, they would have the value 4.
    // If nobody sat at the table, then we should show the split view.
    if (!_isBoardPresent) {
      _showSplitView = true;
    }
    _reset();
  }

  bool get _isBoardPresent => config.croupier.playersFound.values.contains(4);

  @override
  void _reset() {
    super._reset();
    _lastViewType = config.game.viewType;
  }

  bool get _canBuffer {
    HeartsGame game = config.game;
    List<logic_card.Card> playCards =
        game.cardCollections[HeartsGame.offsetPlay + game.playerNumber];
    return game.isPlayer && game.numPlayed >= 1 && playCards.length == 0;
  }

  bool get _shouldUnbuffer {
    HeartsGame game = config.game;
    bool hasPermission = true;
    // TODO(alexfandrianto): https://github.com/vanadium/issues/issues/1098
    // bool hasPermission = game.asking || !_isBoardPresent;
    return game.whoseTurn == game.playerNumber &&
        bufferedPlay.length > 0 &&
        !bufferedPlaying &&
        hasPermission;
  }

  @override
  Widget build(BuildContext context) {
    HeartsGame game = config.game;

    // Reset the game's stored ZCards if the view type changes.
    if (_lastViewType != game.viewType) {
      _reset();
    }

    // If it's our turn and buffered play is not empty, let's play it!
    // Set a flag to ensure that we only play it once.
    if (_shouldUnbuffer) {
      _makeGameMoveCallback(bufferedPlay[0],
          game.cardCollections[HeartsGame.offsetPlay + game.playerNumber]);
      bufferedPlaying = true;
    }

    // If all cards were played, we can safely clear bufferedPlay.
    if (game.allPlayed) {
      _clearBufferedPlay();
    }

    // Hearts Widget
    Widget heartsWidget = new Container(
        decoration: new BoxDecoration(backgroundColor: Colors.grey[300]),
        child: buildHearts());

    List<Widget> children = new List<Widget>();
    children.add(new Container(
        decoration: new BoxDecoration(backgroundColor: Colors.grey[300]),
        width: config.width,
        height: config.height,
        child: heartsWidget));
    List<int> visibleCardCollectionIndexes = new List<int>();
    if (game.phase != HeartsPhase.deal && game.phase != HeartsPhase.score) {
      int playerNum = game.playerNumber;
      if (game.viewType == HeartsType.player) {
        switch (game.phase) {
          case HeartsPhase.pass:
            visibleCardCollectionIndexes.add(HeartsGame.offsetPass + playerNum);
            visibleCardCollectionIndexes.add(HeartsGame.offsetHand + playerNum);
            break;
          case HeartsPhase.take:
            visibleCardCollectionIndexes
                .add(HeartsGame.offsetPass + game.takeTarget);
            visibleCardCollectionIndexes.add(HeartsGame.offsetHand + playerNum);
            break;
          case HeartsPhase.play:
            if (_showSplitView) {
              for (int i = 0; i < 4; i++) {
                visibleCardCollectionIndexes.add(HeartsGame.offsetHand + i);
                visibleCardCollectionIndexes.add(HeartsGame.offsetTrick + i);
                visibleCardCollectionIndexes.add(HeartsGame.offsetPlay + i);
              }
            } else {
              visibleCardCollectionIndexes
                  .add(HeartsGame.offsetPlay + playerNum);
              visibleCardCollectionIndexes
                  .add(HeartsGame.offsetHand + playerNum);
            }

            break;
          default:
            break;
        }
      } else {
        // A board will need to see these things.
        for (int i = 0; i < 4; i++) {
          visibleCardCollectionIndexes.add(HeartsGame.offsetPlay + i);
          visibleCardCollectionIndexes.add(HeartsGame.offsetPass + i);
          visibleCardCollectionIndexes.add(HeartsGame.offsetHand + i);
          visibleCardCollectionIndexes.add(HeartsGame.offsetTrick + i);
        }
      }
    }
    children.add(this.buildCardAnimationLayer(visibleCardCollectionIndexes));

    return new Container(
        width: config.width,
        height: config.height,
        child: new Stack(children: children));
  }

  void _switchViewCallback() {
    HeartsGame game = config.game;
    setState(() {
      if (game.viewType == HeartsType.player) {
        game.viewType = HeartsType.board;
      } else {
        game.viewType = HeartsType.player;
        if (!game.isPlayer) {
          game.playerNumber = 0; // avoid accidental red screen
        }
      }
    });
  }

  // Passing between the temporary pass list and the player's hand.
  // Does not actually move anything in game logic terms.
  void _uiPassCardCallback(logic_card.Card card, List<logic_card.Card> dest) {
    setState(() {
      if (passingCards1.contains(card)) {
        passingCards1.remove(card);
      }
      if (passingCards2.contains(card)) {
        passingCards2.remove(card);
      }
      if (passingCards3.contains(card)) {
        passingCards3.remove(card);
      }

      if (dest == passingCards1) {
        passingCards1.clear();
        passingCards1.add(card);
      } else if (dest == passingCards2) {
        passingCards2.clear();
        passingCards2.add(card);
      } else if (dest == passingCards3) {
        passingCards3.clear();
        passingCards3.add(card);
      }
    });
  }

  int _compareCards(logic_card.Card a, logic_card.Card b) {
    if (a == b) return 0;
    assert(a.deck == "classic" && b.deck == "classic");
    HeartsGame game = config.game;
    int r = game.getCardSuit(a).compareTo(game.getCardSuit(b));
    if (r != 0) return r;
    return game.getCardValue(a) < game.getCardValue(b) ? -1 : 1;
  }

  void _clearPassing() {
    passingCards1.clear();
    passingCards2.clear();
    passingCards3.clear();
  }

  List<logic_card.Card> _combinePassing() {
    List<logic_card.Card> ls = new List<logic_card.Card>();
    ls.addAll(passingCards1);
    ls.addAll(passingCards2);
    ls.addAll(passingCards3);
    return ls;
  }

  void _clearBufferedPlay() {
    bufferedPlay.clear();
    bufferedPlaying = false;
  }

  // This shouldn't always be here, but for now, we have little choice.
  void _switchPlayersCallback() {
    setState(() {
      config.game.playerNumber = (config.game.playerNumber + 1) % 4;
      _clearPassing(); // Just for sanity.
      _clearBufferedPlay();
    });
  }

  void _makeGamePassCallback() {
    setState(() {
      try {
        config.game.passCards(_combinePassing());
        config.game.debugString = null;
        config.sounds.play("whooshOut");
      } catch (e) {
        print("You can't do that! ${e.toString()}");
        config.game.debugString = "You must pass 3 cards";
      }
    });
  }

  void _makeGameTakeCallback() {
    setState(() {
      try {
        // TODO(alexfandrianto): Another way to clear these passing cards is to
        // do so upon the transition from the pass phase to the take phase.
        // However, since they are never seen outside of the Pass phase, it is
        // also valid to clear them upon taking any cards.
        _clearPassing();
        config.game.takeCards();
        config.game.debugString = null;
        config.sounds.play("whooshIn");
      } catch (e) {
        print("You can't do that! ${e.toString()}");
        config.game.debugString = e.toString();
      }
    });
  }

  void _makeGameMoveCallback(logic_card.Card card, List<logic_card.Card> dest) {
    setState(() {
      HeartsGame game = config.game;

      bool isBufferAttempt = dest == bufferedPlay;

      String reason =
          game.canPlay(game.playerNumber, card, lenient: isBufferAttempt);
      if (reason == null) {
        if (isBufferAttempt) {
          print("Buffering $card...");
          _clearBufferedPlay();
          bufferedPlay.add(card);
        } else {
          // TODO(alexfandrianto): Clean up soon.
          // https://github.com/vanadium/issues/issues/1098
          // Automatically ask (for when there is no board).
          /*if (!game.asking && !_isBoardPresent) {
            game.askUI();
          }*/
          game.askUI();
          game.move(card, dest);
          config.sounds.play("whooshOut");
        }
        game.debugString = null;
      } else {
        print("You can't do that! $reason");
        game.debugString = reason;
      }
    });
  }

  void _makeTakeTrickCallback() {
    HeartsGame game = config.game;
    setState(() {
      game.takeTrickUI();
      game.debugString = null;
      config.sounds.play("whooshIn");
    });
  }

  void _endRoundDebugCallback() {
    setState(() {
      config.game.jumpToScorePhaseDebug();
      config.game.debugString = null;
    });
  }

  Widget _makeDebugButtons() {
    if (config.game.debugMode == false) {
      return new Row(children: [
        new Flexible(flex: 4, child: _makeButton('Quit', _quitGameCallback))
      ]);
    }
    return new Row(children: [
      new Flexible(flex: 1, child: new Text('P${config.game.playerNumber}')),
      new Flexible(
          flex: 5, child: _makeButton('Switch Player', _switchPlayersCallback)),
      new Flexible(
          flex: 5, child: _makeButton('Switch View', _switchViewCallback)),
      new Flexible(
          flex: 5, child: _makeButton('End Round', _endRoundDebugCallback)),
      new Flexible(flex: 4, child: _makeButton('Quit', _quitGameCallback))
    ]);
  }

  @override
  Widget _makeButton(String text, VoidCallback callback,
      {bool inactive: false}) {
    var borderColor = inactive ? Colors.grey[500] : Colors.white;
    var backgroundColor = inactive ? Colors.grey[500] : null;
    return new FlatButton(
        child: new Container(
            decoration: new BoxDecoration(
                border: new Border.all(width: 1.0, color: borderColor),
                backgroundColor: backgroundColor),
            padding: new EdgeInsets.all(10.0),
            child: new Text(text)),
        onPressed: inactive ? null : callback);
  }

  Widget buildHearts() {
    if (config.game.viewType == HeartsType.board) {
      return buildHeartsBoard();
    }

    switch (config.game.phase) {
      case HeartsPhase.deal:
        return showDeal();
      case HeartsPhase.pass:
        return showPass();
      case HeartsPhase.take:
        return showTake();
      case HeartsPhase.play:
        return showPlay();
      case HeartsPhase.score:
        return showScore();
      default:
        assert(false);
        return null;
    }
  }

  Widget buildHeartsBoard() {
    List<Widget> kids = new List<Widget>();
    switch (config.game.phase) {
      case HeartsPhase.deal:
      case HeartsPhase.pass:
      case HeartsPhase.take:
      case HeartsPhase.play:
        kids.add(showBoard());
        break;
      case HeartsPhase.score:
        return showScore();
      default:
        assert(false);
        return null;
    }
    kids.add(_makeDebugButtons());
    return new Column(
        children: kids, mainAxisAlignment: MainAxisAlignment.spaceBetween);
  }

  Widget showBoard() {
    return new HeartsBoard(config.croupier, config.sounds,
        width: config.width,
        height: 0.825 * config.height, setGameStateCallback: () {
      setState(() {});
    });
  }

  String _getName(int playerNumber) {
    return config.croupier.settingsFromPlayerNumber(playerNumber)?.name;
  }

  HeartsStatus _getStatus() {
    HeartsGame game = config.game;

    String status;
    bool isPlayer = false;
    bool isError = false;
    switch (game.phase) {
      case HeartsPhase.play:
        // Who's turn is it?
        String name = _getName(game.whoseTurn) ?? "Player ${game.whoseTurn}";
        isPlayer = game.whoseTurn == game.playerNumber;
        status = isPlayer ? "Your turn" : "$name's turn";

        // Override if someone is taking a trick.
        if (game.allPlayed) {
          int winner = game.determineTrickWinner();
          String trickTaker = _getName(winner) ?? "Player $winner";
          isPlayer = winner == game.playerNumber;
          status = isPlayer ? "Your trick" : "$trickTaker's trick";
        }
        break;
      case HeartsPhase.pass:
        if (game.hasPassed(game.playerNumber)) {
          status = "Waiting for cards...";
        } else {
          String name =
              _getName(game.passTarget) ?? "Player ${game.passTarget}";
          status = "Pass to $name";
          isPlayer = true;
        }
        break;
      case HeartsPhase.take:
        if (game.hasTaken(game.playerNumber)) {
          status = "Waiting for other players...";
        } else {
          String name =
              _getName(game.takeTarget) ?? "Player ${game.takeTarget}";
          status = "Take from $name";
          isPlayer = true;
        }
        break;
      default:
        break;
    }

    // Override if there is a debug string.
    if (game.debugString != null) {
      status = game.debugString;
      isError = true;
    }

    return new HeartsStatus(status, isPlayer, isError);
  }

  Widget _buildNumTrickIcon() {
    HeartsGame game = config.game;

    int numTrickCards =
        game.cardCollections[HeartsGame.offsetTrick + game.playerNumber].length;
    int numTricks = numTrickCards ~/ 4;

    IconData iconData = Icons.filter_9_plus;
    if (numTricks == 0) {
      iconData = Icons.filter_none;
    } else if (numTricks == 1) {
      iconData = Icons.filter_1;
    } else if (numTricks == 2) {
      iconData = Icons.filter_2;
    } else if (numTricks == 3) {
      iconData = Icons.filter_3;
    } else if (numTricks == 4) {
      iconData = Icons.filter_4;
    } else if (numTricks == 5) {
      iconData = Icons.filter_5;
    } else if (numTricks == 6) {
      iconData = Icons.filter_6;
    } else if (numTricks == 7) {
      iconData = Icons.filter_7;
    } else if (numTricks == 8) {
      iconData = Icons.filter_8;
    } else if (numTricks == 9) {
      iconData = Icons.filter_9;
    }

    return new Icon(icon: iconData);
  }

  Widget _buildStatusBar() {
    HeartsGame game = config.game;

    List<Widget> statusBarWidgets = new List<Widget>();
    HeartsStatus status = _getStatus();
    statusBarWidgets.add(new Flexible(
        flex: 1, child: new Text(status.text, style: style.Text.largeStyle)));

    switch (game.phase) {
      case HeartsPhase.play:
        if (game.allPlayed &&
            game.determineTrickWinner() == game.playerNumber &&
            _showSplitView) {
          statusBarWidgets.add(new Flexible(
              flex: 0,
              child: new GestureDetector(
                  onTap: _makeTakeTrickCallback,
                  child: new Container(
                      decoration: style.Box.brightBackground,
                      margin: style.Spacing.smallPaddingSide,
                      padding: style.Spacing.smallPadding,
                      child: new Text("Take Cards",
                          style: style.Text.largeStyle)))));
        }
        statusBarWidgets.add(_buildNumTrickIcon());
        statusBarWidgets.add(new IconButton(
            icon: Icons.swap_vert,
            onPressed: () {
              setState(() {
                _showSplitView = !_showSplitView;
              });
            }));
        break;
      case HeartsPhase.pass:
      case HeartsPhase.take:
        // TODO(alexfandrianto): Icons for arrow_upward and arrow_downward were
        // just added to the material icon list. However, they are not available
        // through Flutter yet.
        double rotationAngle = 0.0; // right
        switch (game.roundNumber % 4) {
          case 1:
            rotationAngle = math.PI; // left
            break;
          case 2:
            rotationAngle = -math.PI / 2; // up
            break;
        }
        if (game.phase == HeartsPhase.take) {
          rotationAngle = rotationAngle + math.PI; // opposite
        }
        statusBarWidgets.add(new Transform(
            transform:
                new vector_math.Matrix4.identity().rotateZ(rotationAngle),
            alignment: new FractionalOffset(0.5, 0.5),
            child: new Icon(icon: Icons.arrow_forward)));
        break;
      default:
        break;
    }

    BoxDecoration decoration = style.Box.background;
    if (status.isPlayer) {
      decoration = style.Box.liveBackground;
    }
    if (status.isError) {
      decoration = style.Box.errorBackground;
    }

    return new Container(
        padding: new EdgeInsets.all(10.0),
        decoration: decoration,
        child: new Row(
            children: statusBarWidgets,
            mainAxisAlignment: MainAxisAlignment.spaceBetween));
  }

  Widget _buildFullMiniBoard() {
    return new Container(
        width: config.width * 0.5,
        height: config.height * 0.25,
        child: new HeartsBoard(config.croupier, config.sounds,
            width: config.width * 0.5,
            height: config.height * 0.25,
            cardWidth: config.height * 0.1,
            cardHeight: config.height * 0.1,
            isMini: true,
            gameAcceptCallback: _makeGameMoveCallback,
            bufferedPlay: _canBuffer ? bufferedPlay : null));
  }

  Widget showPlay() {
    HeartsGame game = config.game;
    int p = game.playerNumber;

    List<Widget> cardCollections = new List<Widget>();

    List<logic_card.Card> playOrBuffer =
        game.cardCollections[p + HeartsGame.offsetPlay];
    if (playOrBuffer.length == 0) {
      playOrBuffer = bufferedPlay;
    }

    if (_showSplitView) {
      cardCollections.add(new Container(
          decoration: style.Box.background,
          child: new Column(
              children: [_buildFullMiniBoard(), _buildStatusBar()])));
    } else {
      Widget playArea = new Container(
          decoration: new BoxDecoration(backgroundColor: Colors.teal[500]),
          width: config.width,
          child: new Center(child: new CardCollectionComponent(
              playOrBuffer, true, CardCollectionOrientation.show1,
              useKeys: true,
              acceptCallback: _makeGameMoveCallback,
              acceptType: p == game.whoseTurn || this._canBuffer
                  ? DropType.card
                  : DropType.none,
              backgroundColor:
                  p == game.whoseTurn ? Colors.white : Colors.grey[500],
              altColor:
                  p == game.whoseTurn ? Colors.grey[200] : Colors.grey[600])));

      cardCollections.add(new Container(
          decoration: style.Box.background,
          child: new BlockBody(children: [_buildStatusBar(), playArea])));
    }

    List<logic_card.Card> cards = game.cardCollections[p];

    // A buffered card won't show up in the normal hand area.
    List<logic_card.Card> remainingCards = new List<logic_card.Card>();
    cards.forEach((logic_card.Card c) {
      if (!bufferedPlay.contains(c)) {
        remainingCards.add(c);
      }
    });

    // You can start playing/buffering if it's your turn or you can buffer.
    bool canTap = game.whoseTurn == game.playerNumber || this._canBuffer;

    CardCollectionComponent c = new CardCollectionComponent(
        remainingCards, game.playerNumber == p, CardCollectionOrientation.suit,
        dragChildren: true, // Can drag, but may not have anywhere to drop
        cardTapCallback: canTap
            ? (logic_card.Card card) =>
                (_makeGameMoveCallback(card, playOrBuffer))
            : null,
        comparator: _compareCards,
        width: config.width,
        useKeys: true);
    cardCollections.add(new BlockBody(children: [c, _makeDebugButtons()]));

    return new Column(
        children: cardCollections,
        mainAxisAlignment: MainAxisAlignment.spaceBetween);
  }

  Widget showScore() {
    HeartsGame game = config.game;

    Widget w;
    if (game.hasGameEnded) {
      w = new Text("Game Over!");
    } else if (!game.isPlayer || game.ready[game.playerNumber]) {
      w = new Text("Waiting for other players...");
    } else {
      w = _makeButton('New Round', game.setReadyUI);
    }

    bool isTall = MediaQuery.of(context).orientation == Orientation.portrait;
    FlexDirection crossDirection =
        isTall ? FlexDirection.horizontal : FlexDirection.vertical;
    FlexDirection mainDirection =
        isTall ? FlexDirection.vertical : FlexDirection.horizontal;
    TextStyle bigStyle = isTall ? style.Text.hugeStyle : style.Text.largeStyle;
    TextStyle bigRedStyle =
        isTall ? style.Text.hugeRedStyle : style.Text.largeRedStyle;

    List<Widget> scores = new List<Widget>();
    scores.add(new Flexible(
        child: new Flex(children: [
          new Flexible(
              child: new Center(child: new Text("Score:", style: bigStyle)),
              flex: 1),
          new Flexible(
              child: new Center(child: new Text("Round", style: bigStyle)),
              flex: 1),
          new Flexible(
              child: new Center(child: new Text("Total", style: bigStyle)),
              flex: 1)
        ], direction: crossDirection),
        flex: 1));
    for (int i = 0; i < 4; i++) {
      bool isMaxForRound =
          game.deltaScores.reduce(math.max) == game.deltaScores[i];
      bool isMaxOverall = game.scores.reduce(math.max) == game.scores[i];

      TextStyle deltaStyle = isMaxForRound ? bigRedStyle : bigStyle;
      TextStyle scoreStyle = isMaxOverall ? bigRedStyle : bigStyle;

      scores.add(new Flexible(
          child: new Flex(
              children: [
                new Flexible(
                    child: new CroupierProfileComponent(
                        settings: config.croupier.settingsFromPlayerNumber(i)),
                    flex: 1),
                new Flexible(
                    child: new Center(child: new Text("${game.deltaScores[i]}",
                        style: deltaStyle)),
                    flex: 1),
                new Flexible(
                    child: new Center(
                        child:
                            new Text("${game.scores[i]}", style: scoreStyle)),
                    flex: 1)
              ],
              direction: crossDirection,
              crossAxisAlignment: CrossAxisAlignment.stretch),
          flex: 2));
    }
    return new Column(children: [
      new Flexible(
          child: new Flex(children: scores, direction: mainDirection), flex: 7),
      new Flexible(child: w, flex: 1),
      new Flexible(child: _makeDebugButtons(), flex: 1)
    ]);
  }

  Widget showDeal() {
    return new Container(
        decoration: new BoxDecoration(backgroundColor: Colors.pink[500]),
        child: new Column(children: [
          new Text('Player ${config.game.playerNumber}'),
          new Text('Waiting for Deal...'),
          _makeDebugButtons()
        ], mainAxisAlignment: MainAxisAlignment.spaceBetween));
  }

  Widget _helpPassTake(
      String name,
      List<logic_card.Card> c1,
      List<logic_card.Card> c2,
      List<logic_card.Card> c3,
      List<logic_card.Card> hand,
      AcceptCb cb,
      VoidCallback buttoncb) {
    bool completed = (buttoncb == null);
    bool draggable = (cb != null) && !completed;

    List<Widget> topCardWidgets = new List<Widget>();
    AcceptCb topCb = completed ? null : cb;
    topCardWidgets.add(_topCardWidget(c1, topCb));
    topCardWidgets.add(_topCardWidget(c2, topCb));
    topCardWidgets.add(_topCardWidget(c3, topCb));
    topCardWidgets.add(_makeButton(name, buttoncb, inactive: completed));

    Color bgColor = completed ? Colors.teal[600] : Colors.teal[500];

    Widget statusBar = _buildStatusBar();

    Widget topArea = new Container(
        decoration: new BoxDecoration(backgroundColor: bgColor),
        padding: new EdgeInsets.all(10.0),
        width: config.width,
        child: new Row(
            children: topCardWidgets,
            mainAxisAlignment: MainAxisAlignment.spaceBetween));
    Widget combinedTopArea = new BlockBody(children: [statusBar, topArea]);

    List<logic_card.Card> emptyC;
    if (c1.length == 0) {
      emptyC = c1;
    } else if (c2.length == 0) {
      emptyC = c2;
    } else {
      emptyC = c3; // even if c3 is already filled, it will be replaced.
    }

    Widget handArea = new CardCollectionComponent(
        hand, true, CardCollectionOrientation.suit,
        dragChildren: draggable,
        comparator: _compareCards,
        width: config.width,
        acceptCallback: cb,
        acceptType: draggable ? DropType.card : null,
        cardTapCallback:
            draggable ? (logic_card.Card c) => cb(c, emptyC) : null,
        backgroundColor: Colors.grey[500],
        altColor: Colors.grey[700],
        useKeys: true);

    Widget combinedBottomArea =
        new BlockBody(children: [handArea, _makeDebugButtons()]);

    return new Column(
        children: <Widget>[combinedTopArea, combinedBottomArea],
        mainAxisAlignment: MainAxisAlignment.spaceBetween);
  }

  Widget _topCardWidget(List<logic_card.Card> cards, AcceptCb cb) {
    HeartsGame game = config.game;
    List<logic_card.Card> passCards =
        game.cardCollections[game.playerNumber + HeartsGame.offsetPass];

    Widget ccc = new CardCollectionComponent(
        cards, true, CardCollectionOrientation.show1,
        dragChildren: cb != null,
        acceptCallback: cb,
        acceptType: cb != null ? DropType.card : null,
        cardTapCallback:
            cb != null ? (logic_card.Card c) => cb(c, passCards) : null,
        backgroundColor: Colors.white,
        altColor: Colors.grey[200],
        useKeys: true);

    if (cb == null) {
      ccc = new Container(child: ccc);
    }

    return ccc;
  }

  // Pass Phase Screen: Show the cards being passed and the player's remaining cards.
  Widget showPass() {
    HeartsGame game = config.game;

    List<logic_card.Card> passCards =
        game.cardCollections[game.playerNumber + HeartsGame.offsetPass];

    List<logic_card.Card> playerCards = game.cardCollections[game.playerNumber];
    List<logic_card.Card> remainingCards = new List<logic_card.Card>();
    playerCards.forEach((logic_card.Card c) {
      if (!passingCards1.contains(c) &&
          !passingCards2.contains(c) &&
          !passingCards3.contains(c)) {
        remainingCards.add(c);
      }
    });

    bool hasPassed = passCards.length != 0;

    return _helpPassTake(
        "Pass",
        passingCards1,
        passingCards2,
        passingCards3,
        remainingCards,
        _uiPassCardCallback,
        hasPassed ? null : _makeGamePassCallback);
  }

  // Take Phase Screen: Show the cards the player has received and the player's hand.
  Widget showTake() {
    HeartsGame game = config.game;

    List<logic_card.Card> playerCards = game.cardCollections[game.playerNumber];
    List<logic_card.Card> takeCards =
        game.cardCollections[game.takeTarget + HeartsGame.offsetPass];

    bool hasTaken = takeCards.length == 0;

    List<logic_card.Card> take1 =
        takeCards.length != 0 ? takeCards.sublist(0, 1) : [];
    List<logic_card.Card> take2 =
        takeCards.length != 0 ? takeCards.sublist(1, 2) : [];
    List<logic_card.Card> take3 =
        takeCards.length != 0 ? takeCards.sublist(2, 3) : [];

    return _helpPassTake("Take", take1, take2, take3, playerCards, null,
        hasTaken ? null : _makeGameTakeCallback);
  }
}

class HeartsArrangeComponent extends GameArrangeComponent {
  HeartsArrangeComponent(Croupier croupier,
      {double width, double height, Key key})
      : super(croupier, width: width, height: height, key: key);

  @override
  HeartsArrangeComponentState createState() =>
      new HeartsArrangeComponentState();
}

class HeartsArrangeComponentState extends State<HeartsArrangeComponent> {
  bool isTable; // Must first ask what kind of device this is. Starts unset.
  bool fallback = false; // Set to true to switch to the old arrange players.

  static final IconData personIcon = Icons.person_outline;
  static final IconData tableIcon = Icons.tablet;

  @override
  Widget build(BuildContext context) {
    if (isTable == null) {
      return _buildAskDeviceType();
    }
    if (isTable) {
      return _buildTableArrangePlayers();
    }
    if (fallback) {
      return _buildFallbackArrangePlayers();
    }
    return _buildPlayerArrangePlayers();
  }

  Widget _buildAskDeviceType() {
    return new Container(
        decoration: style.Box.liveNow,
        height: config.height,
        width: config.width,
        child: new Column(children: [
          new Text("Play Hearts as a...", style: style.Text.hugeStyle),
          new FlatButton(
              child: new Row(children: [
                new Icon(size: 48.0, icon: personIcon),
                new Text("Player", style: style.Text.largeStyle)
              ], mainAxisAlignment: MainAxisAlignment.collapse),
              color: style.secondaryTextColor,
              onPressed: () {
                setState(() {
                  isTable = false;
                });
              }),
          new FlatButton(
              child: new Row(children: [
                new Icon(size: 48.0, icon: tableIcon),
                new Text("Table", style: style.Text.largeStyle)
              ], mainAxisAlignment: MainAxisAlignment.collapse),
              color: style.secondaryTextColor,
              onPressed: () {
                setState(() {
                  isTable = true;
                });
                // Also sit at the table.
                config.croupier.settingsManager.setPlayerNumber(
                    config.croupier.game.gameID,
                    config.croupier.settings.userID,
                    4);
              })
        ], crossAxisAlignment: CrossAxisAlignment.center));
  }

  int get numSitting => config.croupier.playersFound.values.where((int index) {
        return index != null && index >= 0 && index < 4;
      }).length;

  Widget _buildTableArrangePlayers() {
    int arrangeID; // Starts unset.
    String status = "";
    bool canStart = false;
    if (numSitting < 4) {
      // We still need people to sit.
      // Only include non-table and non-sitting devices in this search.
      // Note that this means it's possible arrangeID is null.
      arrangeID = config.croupier.playersFound.keys.firstWhere((int playerID) {
        int index = config.croupier.playersFound[playerID];
        return index == null || index < 0;
      }, orElse: () => null);
      status = arrangeID != null ? "Tap to place" : "Waiting for players...";
    } else {
      status = "Play Hearts!";
      canStart = true;
    }

    List<Widget> children = [new Text(status, style: style.Text.hugeStyle)];
    // Also add the player's name (using a placeholder if that's not possible).
    if (arrangeID != null) {
      children.add(new CroupierProfileComponent.textOnly(
          settings: config.croupier.settingsEveryone[arrangeID]));
    }

    // You will need to show a Start Game button if the table isn't the creator.
    // Replace the status text with a status button instead.
    if (canStart && !config.croupier.game.isCreator) {
      children = [
        new FlatButton(
            child: new Text(status, style: style.Text.hugeStyle),
            color: style.theme.accentColor,
            onPressed: () {
              config.croupier.settingsManager
                  .setGameStatus(config.croupier.game.gameID, "RUNNING");
            })
      ];
    }
    Widget firstChild = new Row(
        children: children, mainAxisAlignment: MainAxisAlignment.collapse);

    return new Container(
        decoration: style.Box.liveNow,
        height: config.height,
        width: config.width,
        child: new Column(children: [
          firstChild,
          new Flexible(child: _buildArrangeTable(activeID: arrangeID))
        ], crossAxisAlignment: CrossAxisAlignment.center));
  }

  Widget _buildPlayerArrangePlayers() {
    List<Widget> children = <Widget>[
      new Text("Waiting for game setup...", style: style.Text.hugeStyle)
    ];
    if (config.croupier.game.isCreator) {
      children.add(new FlatButton(
          child: new Text("Manual Setup", style: style.Text.largeStyle),
          color: style.theme.accentColor,
          onPressed: () {
            setState(() {
              fallback = true;
            });
          }));
    }

    return new Container(
        decoration: style.Box.liveNow,
        height: config.height,
        width: config.width,
        child: new Column(
            children: children, crossAxisAlignment: CrossAxisAlignment.center));
  }

  Widget _buildFallbackArrangePlayers() {
    return new Container(
        decoration: style.Box.liveNow,
        height: config.height,
        width: config.width,
        child: _buildArrangeTable(canDragTo: true));
  }

  Widget _buildArrangeTable({int activeID: null, bool canDragTo: false}) {
    int numAtTable = config.croupier.playersFound.values
        .where((int playerNumber) => playerNumber == 4)
        .length;
    return new Column(
        children: [
          new Flexible(
              flex: 1,
              child: new Row(
                  children: [
                    _buildEmptySlot(),
                    _buildSlot(personIcon, 2, activeID, canDragTo),
                    _buildEmptySlot()
                  ],
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.stretch)),
          new Flexible(
              flex: 1,
              child: new Row(
                  children: [
                    _buildSlot(personIcon, 1, activeID, canDragTo),
                    _buildSlot(tableIcon, 4, activeID, canDragTo,
                        extra: "x$numAtTable"),
                    _buildSlot(personIcon, 3, activeID, canDragTo)
                  ],
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.stretch)),
          new Flexible(
              flex: 1,
              child: new Row(
                  children: [
                    _buildEmptySlot(),
                    _buildSlot(personIcon, 0, activeID, canDragTo),
                    _buildEmptySlot()
                  ],
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.stretch))
        ],
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.stretch);
  }

  Widget _buildEmptySlot() {
    return new Flexible(flex: 1, child: new Text(""));
  }

  Widget _buildSlot(IconData iconData, int index, int activeID, bool canDragTo,
      {String extra: ""}) {
    Widget slotWidget = new Row(
        children: [
          new Icon(size: 48.0, icon: iconData),
          new Text(extra, style: style.Text.largeStyle)
        ],
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center);

    bool isMe = config.croupier.game.playerNumber == index;
    bool isPlayerIndex = index >= 0 && index < 4;
    bool isTableIndex = index == 4;
    bool seatTaken = (isPlayerIndex || (isTableIndex && isMe)) &&
        config.croupier.playersFound.containsValue(index);
    if (seatTaken) {
      // Note: If more than 1 person is in the seat, it may no longer show you.
      CroupierSettings cs = config.croupier.settingsFromPlayerNumber(index);
      CroupierProfileComponent cpc =
          new CroupierProfileComponent.horizontal(settings: cs);
      slotWidget =
          new Draggable<CroupierSettings>(child: cpc, feedback: cpc, data: cs);
    }

    Widget dragTarget = new DragTarget<CroupierSettings>(
        builder: (BuildContext context, List<CroupierSettings> data, _) {
          return new GestureDetector(
              onTap: () {
                if (activeID != null) {
                  config.croupier.settingsManager.setPlayerNumber(
                      config.croupier.game.gameID, activeID, index);
                }
              },
              child: new Container(
                  constraints: const BoxConstraints.expand(),
                  decoration:
                      isMe ? style.Box.liveBackground : style.Box.border,
                  child: new Center(child: slotWidget)));
        },
        onAccept: (CroupierSettings cs) {
          config.croupier.settingsManager
              .setPlayerNumber(config.croupier.game.gameID, cs.userID, index);
        },
        onWillAccept: (_) => canDragTo);

    return new Flexible(flex: 1, child: dragTarget);
  }
}

class HeartsStatus {
  final String text;
  final bool isPlayer;
  final bool isError;

  const HeartsStatus(this.text, this.isPlayer, this.isError);
}
