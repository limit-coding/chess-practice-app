// Parses the two pieces of engine output that game review is built on:
// the "MESSAGE Speed ... | Eval <value> | ..." line and the "MESSAGE
// Bestline <moves>" line emitted at the end of every search (see
// native/rapfi/Rapfi/search/searchoutput.cpp printSearchEnds, and
// core/iohelper.cpp for the `Value`/`Pos` stream formats being parsed here).

/// Matches Rapfi's own mate-distance convention (core/types.h): a value's
/// magnitude approaching this means "mate found", not a normal position
/// score. Non-mate evals are printed as plain integers by the engine; this
/// module re-encodes mate scores onto the same numeric line so evals stay
/// directly comparable.
const int valueMate = 30000;

/// Parses one value token as printed by Rapfi's `Value` stream formatter: a
/// plain integer, or `+M`/`-M` followed by a mate-in-n-plies count, or the
/// rare `+M*`/`-M*`/`VAL_INF`/`-VAL_INF` edge cases. Returns `null` if
/// [token] doesn't match any of these (e.g. `VAL_NONE`).
int? parseEngineValue(String token) {
  switch (token) {
    case 'VAL_INF':
      return valueMate + 1;
    case '-VAL_INF':
      return -(valueMate + 1);
    case '+M*':
      return valueMate;
    case '-M*':
      return -valueMate;
  }

  final mateMatch = RegExp(r'^([+-])M(\d+)$').firstMatch(token);
  if (mateMatch != null) {
    final sign = mateMatch.group(1) == '-' ? -1 : 1;
    final ply = int.parse(mateMatch.group(2)!);
    return sign * (valueMate - ply);
  }

  return int.tryParse(token);
}

/// Extracts the value from a `"MESSAGE Speed ... | Eval <value> | ..."`
/// line (or any string containing an `Eval <token>` fragment).
int? parseEvalFromMessageLine(String line) {
  final match = RegExp(r'Eval\s+(\S+)').firstMatch(line);
  if (match == null) return null;
  return parseEngineValue(match.group(1)!);
}

/// Parses one `"H8"`-style move label (column letter + 1-indexed row, see
/// `operator<<(ostream&, Pos)`) into a 0-indexed `(x, y)` pair. Returns
/// `null` for anything else (e.g. `"Pass"`, `"None"`).
(int, int)? parseLabelCoord(String token) {
  if (token.isEmpty) return null;
  final letter = token[0].toUpperCase().codeUnitAt(0);
  if (letter < 'A'.codeUnitAt(0) || letter > 'Z'.codeUnitAt(0)) return null;
  final row = int.tryParse(token.substring(1));
  if (row == null || row < 1) return null;
  return (letter - 'A'.codeUnitAt(0), row - 1);
}

/// Extracts the principal variation from a `"MESSAGE Bestline H8 G8 ..."`
/// line, in move order. Unparseable tokens (there shouldn't be any in
/// practice) are skipped rather than aborting the whole line.
List<(int, int)> parseBestlineFromMessageLine(String line) {
  const prefix = 'Bestline';
  final idx = line.indexOf(prefix);
  if (idx < 0) return const [];
  final rest = line.substring(idx + prefix.length).trim();
  if (rest.isEmpty) return const [];

  final result = <(int, int)>[];
  for (final token in rest.split(RegExp(r'\s+'))) {
    final pos = parseLabelCoord(token);
    if (pos != null) result.add(pos);
  }
  return result;
}
