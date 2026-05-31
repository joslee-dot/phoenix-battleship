import React from 'react';

class MusicPlayer extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      playing: false,
      ready: false,
    };
    this._player = null;
    this._onReady = this._onReady.bind(this);
    this._onStateChange = this._onStateChange.bind(this);
  }

  componentDidMount() {
    this._initPlayer();
  }

  componentWillUnmount() {
    if (this._player) {
      this._player.destroy();
      this._player = null;
    }
  }

  _initPlayer() {
    if (window.YT && window.YT.Player) {
      this._createPlayer();
    } else {
      window.onYouTubeIframeAPIReady = () => this._createPlayer();
    }
  }

  _createPlayer() {
    this._player = new window.YT.Player('yt-music-player', {
      height: '0',
      width: '0',
      videoId: 'Q5GswxdmfPI',
      playerVars: {
        autoplay: 0,
        loop: 1,
        playlist: 'Q5GswxdmfPI',
      },
      events: {
        onReady: this._onReady,
        onStateChange: this._onStateChange,
      },
    });
  }

  _onReady() {
    this.setState({ ready: true });
    if (this._player) {
      this._player.setVolume(50);
    }
  }

  _onStateChange(event) {
    this.setState({ playing: event.data === window.YT.PlayerState.PLAYING });
  }

  _togglePlay() {
    if (!this._player || !this.state.ready) return;

    if (this.state.playing) {
      this._player.pauseVideo();
    } else {
      this._player.playVideo();
    }
  }

  render() {
    const { playing, ready } = this.state;

    return (
      <div id="music-player-widget">
        <div id="yt-music-player" style={{ display: 'none' }}></div>
        <button
          onClick={() => this._togglePlay()}
          disabled={!ready}
          title={playing ? 'Pause Music' : 'Play Music - Bad Bunny: MR. OCTOBER'}>
          <i className={`fa ${playing ? 'fa-pause' : 'fa-music'}`}></i>
          <span className="song-label">
            {playing ? 'MR. OCTOBER' : 'Play Music'}
          </span>
        </button>
      </div>
    );
  }
}

export default MusicPlayer;
