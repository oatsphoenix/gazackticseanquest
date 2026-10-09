GaZacktic Seanquest - Galactic Conquest board for Star Wars Battlefront II
===========================================================================

Run it
  Open index.html in a browser (double-click). No install, no server, no internet.
  Keep three.js in the same folder as index.html.

Files
  index.html   The whole game: styles at the top, then the page layout, then the script.
  three.js     three.js r160, the 3D library (unminified, unchanged from the official build).

Where things are in index.html (search for these headings)
  state           The default board (planets, maps, lanes), players and the credit rules.
  game actions    Buying, battles, end of turn, era roll, moving fleets.
  three.js scene  Stars, planets, lanes and fleets.
  pointer input   Mouse controls for the board.
  menus           The side panels and their buttons.

Saving and sharing
  The game saves itself in the browser it is opened in.
  To share a game: Board data > Export, send the .json file, and the other player uses Import.
