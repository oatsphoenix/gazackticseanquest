GaZacktic Seanquest - Galactic Conquest board for Star Wars Battlefront II
===========================================================================

Run it
  Open index.html in a browser (double-click). No install, no server, no internet.
  Keep three.js in the same folder as index.html.

Files
  index.html   The whole game: styles at the top, then the page layout, then the script.
  three.js     three.js r160, the 3D library (unminified, unchanged from the official build).
  mods/        Windows installer for the Battlefront II mod set and the game launcher.
  fonts/       The three typefaces the board uses, with their licences (SIL Open Font License):
               Oxanium (titles, numbers), Rajdhani (everything else), Share Tech Mono (mission codes).

Where things are in index.html (search for these headings)
  state           The default board (planets, maps, lanes), players and the credit rules.
  game actions    Buying, battles, end of turn, era roll, moving fleets.
  three.js scene  Stars, planets, lanes and fleets.
  pointer input   Mouse controls for the board.
  menus           The side panels and their buttons.

Playing online
  Play online > Host this game gives a room code and a link. The other player opens the link.
  One browser hosts the game and the other connects straight to it; both need the page open.
  peerjs.min.js (PeerJS 1.5.4, unchanged) is the library that makes that connection.

Battles
  Select a planet and press Battle on a map. The battle card sets the era, sides and mode, shows
  the game's mission code, and records who won. Launch game needs the launcher from mods/.

Saving and sharing
  The game saves itself in the browser it is opened in.
  To share a game: Board data > Export, send the .json file, and the other player uses Import.
