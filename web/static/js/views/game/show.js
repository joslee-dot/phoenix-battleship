import React, { PropTypes }   from 'react';
import { Link }               from 'react-router';
import { Socket }             from 'phoenix';
import { connect }            from 'react-redux';
import { joinGame }           from '../../actions/game';
import { resetGame }          from '../../actions/game';
import ShipSelector           from '../../components/game/ship_selector';
import Board                  from '../../components/game/board';
import MyBoard                from '../../components/game/my_board';
import OpponentBoard          from '../../components/game/opponent_board';
import Chat                   from '../../components/game/chat';
import Header                 from '../../components/game/header';
import Instructions           from '../../components/game/instructions';
import Logo                   from '../../components/common/logo';
import MusicPlayer            from '../../components/game/music_player';
import { setDocumentTitle }   from '../../utils';

class GameShowView extends React.Component {
  componentDidMount() {
    this._joinGame();
  }

  componentWillUnmount() {
    const { dispatch, gameChannel } = this.props;

    if (gameChannel != null) gameChannel.leave();

    dispatch(resetGame());
  }

  _joinGame() {
    const { dispatch, playerId, socket, location } = this.props;
    const gameId = this.props.params.id;
    const isAI = location && location.query && location.query.ai === 'true';

    dispatch(joinGame(socket, playerId, gameId, isAI));
  }

  _opponentIsConnected() {
    const { playerId, game } = this.props;

    return playerId == game.attacker ? game.defender != null : game.attacker != null;
  }

  _renderOpponentBoard() {
    const { dispatch, game, gameChannel, playerId, currentTurn, readyForBattle } = this.props;

    if (!readyForBattle) return (
      <Instructions
        readyForBattle={readyForBattle}
        playerIsAttacker={playerId === game.attacker}/>
    );

    const opponentBoard = game.opponents_board;

    return (
      <div id="opponents_board_container">
        <header>
          <h2>Shooting grid</h2>
        </header>
        <OpponentBoard
          dispatch={dispatch}
          gameChannel={gameChannel}
          data={opponentBoard}
          playerId={playerId}
          currentTurn={currentTurn}/>
        <p>Remaining hit points: {opponentBoard.hit_points}</p>
      </div>
    );
  }

  _renderError() {
    const { error } = this.props;

    if (!error) return false;

    return (
      <div className="error">{error}</div>
    );
  }

  _renderResult() {
    const { game, playerId, winnerId } = this.props;

    const isWinner = playerId === winnerId;
    const heading = isWinner ? 'Victory is Yours!' : 'Defeated!';
    const message = isWinner
      ? 'Yo Ho Ho! You sank the enemy fleet and rule the seas, Captain!'
      : 'Your fleet has been sent to Davy Jones\' locker. Better luck next time, landlubber!';

    setDocumentTitle(`${heading} · #${game.id}`);

    return (
      <div id="game_result">
        <div className="result-overlay">
          <div className="result-icon">{isWinner ? '⚓' : '💀'}</div>
          <h1 className={isWinner ? 'victory' : 'defeat'}>{heading}</h1>
          <p className="result-message">{message}</p>
          <Link to="/" className="play-again-btn">Play Again</Link>
        </div>
      </div>
    );
  }

  _renderGameContent() {
    const { dispatch, game, gameOver, gameChannel, selectedShip, playerId, currentTurn, messages } = this.props;

    if (gameOver) return this._renderResult();

    return (
      <section id="main_section">
        <Header
          game={game}
          playerId={playerId}
          currentTurn={currentTurn} />
        <section id="boards_container">
          <div id="my_board_container">
            <header>
              <h2>Your ships</h2>
            </header>
            <ShipSelector
              dispatch={dispatch}
              game={game}
              selectedShip={selectedShip} />
            <MyBoard
              dispatch={dispatch}
              gameChannel={gameChannel}
              selectedShip={selectedShip}
              data={game.my_board}/>
            {::this._renderError()}
          </div>
          {::this._renderOpponentBoard()}
        </section>
      </section>
    );
  }

  render() {
    const { dispatch, game, gameOver, gameChannel, selectedShip, playerId, currentTurn, messages } = this.props;

    if (!game || (!game.my_board && !gameOver)) return false;

    return (
      <div id="game_show" className="view-container">
        <MusicPlayer />
        {::this._renderGameContent()}
        <Chat
          dispatch={dispatch}
          opponentIsConnected={::this._opponentIsConnected()}
          gameChannel={gameChannel}
          messages={messages}
          playerId={playerId}/>
      </div>
    );
  }
}

const mapStateToProps = (state) => (
  { ...state.session, ...state.game }
);

export default connect(mapStateToProps)(GameShowView);
