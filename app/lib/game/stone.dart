/// A stone color on the board. Black always moves first (the human player).
enum Stone {
  black,
  white;

  Stone get opponent => this == Stone.black ? Stone.white : Stone.black;
}
