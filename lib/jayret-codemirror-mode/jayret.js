// Jayret CodeMirror syntax mode
// Derived from jayret-parley-vscode/syntaxes/jayret.tmLanguage.json
// Stateless for indentation — Jayret is brace-delimited, not indent-sensitive.

(function() {
  "use strict";

  function mkWordSet(words) {
    var s = Object.create(null);
    for (var i = 0; i < words.length; i++) s[words[i]] = true;
    return s;
  }

  var KEYWORDS = mkWordSet([
    // Control flow
    "if", "else", "while", "for", "return", "break", "continue",
    "switch", "case", "yield", "do",
    // Declaration / module
    "data", "import", "as", "from", "file", "provide",
    // Storage modifiers
    "rec", "new", "let", "var",
    // Jayret expression forms
    "block", "ask", "otherwise", "spy",
    // Table column operations
    "sieve", "order", "extend", "select", "extract",
    "using", "ascending", "descending", "row", "table",
    // Primitive type keywords
    "int", "double", "boolean", "String", "void", "Object", "Number", "Any"
  ]);

  var ATOMS = mkWordSet(["true", "false", "null", "nothing", "empty"]);

  var BUILTINS = mkWordSet([
    "print", "tostring",
    "assertEquals", "assertNotEquals",
    "assertTrue", "assertFalse",
    "assertRaises", "assertSatisfies", "assertRoughlyEquals"
  ]);

  CodeMirror.defineMode("jayret", function() {
    return {
      startState: function() {
        return { blockComment: false, inString: false };
      },

      token: function(stream, state) {
        // Multi-line block comment continuation
        if (state.blockComment) {
          if (stream.skipTo("*/")) {
            stream.next(); stream.next();
            state.blockComment = false;
          } else {
            stream.skipToEnd();
          }
          return "comment";
        }

        // Multi-line string continuation
        if (state.inString) {
          while (!stream.eol()) {
            var c = stream.next();
            if (c === "\\") { stream.next(); }
            else if (c === '"') { state.inString = false; break; }
          }
          return "string";
        }

        if (stream.eatSpace()) return null;

        // Line comment
        if (stream.match("//")) {
          stream.skipToEnd();
          return "comment";
        }

        // Block comment
        if (stream.match("/*")) {
          if (stream.skipTo("*/")) {
            stream.next(); stream.next();
          } else {
            stream.skipToEnd();
            state.blockComment = true;
          }
          return "comment";
        }

        // String literal
        if (stream.peek() === '"') {
          stream.next();
          state.inString = true;
          while (!stream.eol()) {
            var ch = stream.next();
            if (ch === "\\") { stream.next(); }
            else if (ch === '"') { state.inString = false; break; }
          }
          return "string";
        }

        // Annotation: @UpperCase (e.g. @Check)
        if (stream.match(/@[A-Z][A-Za-z0-9_]*/)) return "meta";

        // Rough number: ~3.14
        if (stream.match(/~[0-9]+(\.[0-9]+)?/)) return "number";

        // Number: rational N/D, decimal, or integer
        if (stream.match(/[0-9]+([/.][0-9]+)?/)) return "number";

        // Identifier / keyword
        if (stream.match(/[a-zA-Z_][a-zA-Z0-9_-]*/)) {
          var word = stream.current();
          if (ATOMS[word])    return "atom";
          if (KEYWORDS[word]) return "keyword";
          if (BUILTINS[word]) return "builtin";
          if (/^[A-Z]/.test(word)) return "variable-2"; // user-defined type
          return "variable";
        }

        // Two-char operators (checked before single-char)
        if (stream.match("->")) return "operator";
        if (stream.match("==")) return "operator";
        if (stream.match("!=")) return "operator";
        if (stream.match("<=")) return "operator";
        if (stream.match(">=")) return "operator";
        if (stream.match("&&")) return "operator";
        if (stream.match("||")) return "operator";

        // Single-char: consume and classify
        var next = stream.next();
        if (/[+\-*/%=<>!|&^]/.test(next)) return "operator";
        return null;
      },

      lineComment:        "//",
      blockCommentStart:  "/*",
      blockCommentEnd:    "*/"
    };
  });
})();
