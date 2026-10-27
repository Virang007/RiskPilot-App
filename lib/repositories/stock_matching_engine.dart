import 'dart:math';
import '../models/stock_model.dart';

class StockMatchingResult {
  final List<String> detectedTokens;
  final List<StockModel> matchedStocks;

  const StockMatchingResult({
    required this.detectedTokens,
    required this.matchedStocks,
  });
}

class StockMatchingEngine {
  // Trading and noise terms to filter out from OCR detection
  static const Set<String> _stopwords = {
    'BUY',
    'SELL',
    'HOLD',
    'TARGET',
    'TGT',
    'STOPLOSS',
    'SL',
    'CMP',
    'LTP',
    'NSE',
    'BSE',
    'EQ',
    'CALL',
    'PUT',
    'CE',
    'PE',
    'FUT',
    'FUTURE',
    'F&O',
    'RS',
    'INR',
    'QTY',
    'QUANTITY',
    'PRICE',
    'POINTS',
    'PTS',
    'TODAY',
    'INTRADAY',
    'DELIVERY',
    'SHORT',
    'LONG',
    'TERM',
    'HIGH',
    'LOW',
    'OPEN',
    'CLOSE',
    'VOLUME',
    'VOL',
    'CHG',
    'PCT',
    'CHNG',
    'PERCENT',
    'NIFTY',
    'BANKNIFTY',
    'FINNIFTY',
    'SENSEX',
    'AT',
    'FOR',
    'THE',
    'AND',
    'WITH',
    'OF',
    'TO',
    'IN',
    'BY',
    'LTD',
    'LIMITED',
    'PVT',
    'CORP',
    'CORPORATION',
    'CO',
    'COMPANY',
    'INC',
  };

  // Conglomerate/group prefixes that should NEVER broadly match all group stocks
  // when captured in phrases (avoids returning all Tata, Adani, or Bajaj shares).
  static const Set<String> _genericGroupPrefixes = {
    'TATA',
    'ADANI',
    'BAJAJ',
    'BIRLA',
    'MAHINDRA',
    'HDFC',
    'ICICI',
    'KOTAK',
    'GODREJ',
    'JSW',
    'JINDAL',
    'VEDANTA',
    'BHARTI',
    'RELIANCE',
    'BANK',
    'INDIA',
    'INDIAN',
  };

  /// Match extracted raw OCR lines against the complete stock catalog
  StockMatchingResult matchStocks({
    required List<String> rawLines,
    required List<StockModel> allStocks,
  }) {
    if (rawLines.isEmpty || allStocks.isEmpty) {
      return const StockMatchingResult(detectedTokens: [], matchedStocks: []);
    }

    final Set<String> detectedTokens = {};
    final List<String> cleanedPhrases = [];
    final List<String> concatenatedPhrases = [];
    final List<String> individualWords = [];

    // 1. Process each line and normalize
    for (final rawLine in rawLines) {
      final cleanedLine = rawLine
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toUpperCase();

      if (cleanedLine.isEmpty) continue;

      // Extract words excluding stopwords
      final words = cleanedLine.split(' ');
      final List<String> validWordsInLine = [];

      for (final word in words) {
        final w = word.trim();
        if (w.length >= 2 && !_stopwords.contains(w) && !RegExp(r'^\d+$').hasMatch(w)) {
          validWordsInLine.add(w);
          individualWords.add(w);
          detectedTokens.add(w);
        }
      }

      if (validWordsInLine.isNotEmpty) {
        // Multi-word phrase: e.g. "TATA MOTORS", "TATA MORTE", "STATE BANK"
        final fullPhrase = validWordsInLine.join(' ');
        cleanedPhrases.add(fullPhrase);

        // Concatenated without spaces: e.g. "TATAMORTE", "TATAMOTORS"
        final concatPhrase = validWordsInLine.join('');
        concatenatedPhrases.add(concatPhrase);

        // Sliding 2-word n-grams if line has >= 3 words
        if (validWordsInLine.length >= 3) {
          for (int i = 0; i < validWordsInLine.length - 1; i++) {
            cleanedPhrases.add('${validWordsInLine[i]} ${validWordsInLine[i + 1]}');
            concatenatedPhrases.add('${validWordsInLine[i]}${validWordsInLine[i + 1]}');
          }
        }
      }
    }

    if (detectedTokens.isEmpty) {
      return const StockMatchingResult(detectedTokens: [], matchedStocks: []);
    }

    // 2. Score every stock in Dhan NSE database
    final Map<StockModel, double> stockScores = {};

    for (final stock in allStocks) {
      final sym = stock.symbol.toUpperCase().trim();
      final name = stock.name.toUpperCase().trim();
      final nameCleaned = name
          .replaceAll(RegExp(r'\b(LIMITED|LTD|PVT|CORP|CORPORATION|CO|INC)\b'), '')
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final nameConcat = nameCleaned.replaceAll(' ', '');
      final nameWords = nameCleaned.split(' ');

      double bestScore = 0.0;

      // Check concatenated phrases against stock symbol (e.g. TATAMORTE vs TATAMOTORS)
      for (final concat in concatenatedPhrases) {
        // Exact symbol match
        if (concat == sym) {
          bestScore = max(bestScore, 100.0);
          continue;
        }

        // Exact match with concatenated company name
        if (nameConcat.isNotEmpty && concat == nameConcat) {
          bestScore = max(bestScore, 98.0);
          continue;
        }

        // Fuzzy match on symbol (detects transpositions and typos like TATAMORTE -> TATAMOTORS)
        if (concat.length >= 5 && sym.length >= 5) {
          final sim = jaroWinkler(concat, sym);
          if (sim >= 0.82) {
            // Check if both start with the same group prefix (e.g. TATA)
            // If so, the remainder MUST be reasonably similar
            bool remainderMatches = true;
            for (final prefix in _genericGroupPrefixes) {
              if (concat.startsWith(prefix) && sym.startsWith(prefix)) {
                final remConcat = concat.substring(prefix.length);
                final remSym = sym.substring(prefix.length);
                if (remConcat.isNotEmpty && remSym.isNotEmpty) {
                  final remSim = jaroWinkler(remConcat, remSym);
                  if (remSim < 0.65) {
                    remainderMatches = false;
                  }
                }
                break;
              }
            }

            if (remainderMatches) {
              final fuzzyScore = 75.0 + (sim * 22.0); // 75 to 97
              bestScore = max(bestScore, fuzzyScore);
            }
          }
        }
      }

      // Check multi-word phrases (e.g. "TATA MOTORS", "TATA MORTE")
      for (final phrase in cleanedPhrases) {
        final phraseWords = phrase.split(' ');

        if (phraseWords.length >= 2) {
          // Identify any generic group prefix (e.g. "TATA", "ADANI")
          final nonGroupPhraseWords = phraseWords
              .where((w) => !_genericGroupPrefixes.contains(w))
              .toList();

          final nonGroupNameWords = nameWords
              .where((w) => !_genericGroupPrefixes.contains(w))
              .toList();

          // If phrase contains a generic prefix, non-group words MUST match!
          // (e.g. "TATA MOTORS" must match "MOTORS", not "STEEL" or "POWER")
          if (nonGroupPhraseWords.isNotEmpty) {
            bool hasNonGroupMatch = false;
            for (final pWord in nonGroupPhraseWords) {
              // Check against stock name non-group words or symbol
              for (final nWord in nonGroupNameWords) {
                if (pWord == nWord || jaroWinkler(pWord, nWord) >= 0.70) {
                  hasNonGroupMatch = true;
                  break;
                }
              }
              if (sym.contains(pWord) || jaroWinkler(pWord, sym) >= 0.70) {
                hasNonGroupMatch = true;
              }
              if (hasNonGroupMatch) break;
            }

            if (!hasNonGroupMatch) {
              // This stock does not match the specific entity in the group!
              continue;
            }
          }

          // Exact phrase contained in company name
          if (nameCleaned.contains(phrase) || phrase.contains(nameCleaned)) {
            bestScore = max(bestScore, 95.0);
            continue;
          }

          // Fuzzy phrase similarity against company name prefix
          final prefixLen = min(nameCleaned.length, phrase.length + 3);
          final namePrefix = nameCleaned.substring(0, prefixLen);
          final sim = jaroWinkler(phrase, namePrefix);

          if (sim >= 0.80) {
            final fuzzyScore = 75.0 + (sim * 20.0);
            bestScore = max(bestScore, fuzzyScore);
          }
        }
      }

      // Check individual words ONLY if bestScore is still low
      // AND prevent generic group prefixes (like TATA, ADANI, BAJAJ) from matching everything
      if (bestScore < 60.0) {
        for (final word in individualWords) {
          // Exact Symbol match (e.g. RELIANCE, TCS, INFY)
          if (word == sym) {
            bestScore = max(bestScore, 100.0);
            continue;
          }

          // Single word fuzzy match on symbol
          if (word.length >= 5 && sym.length >= 5) {
            final sim = jaroWinkler(word, sym);
            if (sim >= 0.88) {
              bestScore = max(bestScore, 85.0);
              continue;
            }
          }

          // If word is generic group prefix (e.g. "TATA"), NEVER match broad company names!
          if (_genericGroupPrefixes.contains(word)) {
            continue;
          }

          // Distinctive single word company name match (length >= 5)
          if (word.length >= 5) {
            if (nameWords.contains(word)) {
              bestScore = max(bestScore, 70.0);
            }
          }
        }
      }

      if (bestScore >= 60.0) {
        stockScores[stock] = bestScore;
      }
    }

    if (stockScores.isEmpty) {
      return StockMatchingResult(
        detectedTokens: detectedTokens.toList(),
        matchedStocks: const [],
      );
    }

    // 3. Sort by score descending
    final sortedEntries = stockScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final highestScore = sortedEntries.first.value;

    // 4. Strict relevance filter:
    // If top match is strong (>= 80), discard weaker/unrelated matches
    // to strictly prevent returning all unrelated shares of the same group.
    final List<StockModel> filteredStocks = [];
    final minAcceptableScore = highestScore >= 80.0 ? (highestScore - 12.0) : 60.0;

    for (final entry in sortedEntries) {
      if (entry.value >= minAcceptableScore) {
        filteredStocks.add(entry.key);
      }
    }

    return StockMatchingResult(
      detectedTokens: detectedTokens.toList(),
      matchedStocks: filteredStocks.take(10).toList(),
    );
  }

  /// Jaro-Winkler string similarity (0.0 to 1.0)
  static double jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final int matchWindow = max(0, (max(s1.length, s2.length) ~/ 2) - 1);
    final List<bool> s1Matches = List<bool>.filled(s1.length, false);
    final List<bool> s2Matches = List<bool>.filled(s2.length, false);

    int matches = 0;
    for (int i = 0; i < s1.length; i++) {
      final int start = max(0, i - matchWindow);
      final int end = min(s2.length, i + matchWindow + 1);

      for (int j = start; j < end; j++) {
        if (s2Matches[j]) continue;
        if (s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    int k = 0;
    int transpositions = 0;
    for (int i = 0; i < s1.length; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) {
        transpositions++;
      }
      k++;
    }

    final double jaro = (matches / s1.length +
            matches / s2.length +
            (matches - (transpositions / 2)) / matches) /
        3.0;

    // Common prefix scaling (up to 4 characters)
    int prefixLen = 0;
    final int maxPrefix = min(4, min(s1.length, s2.length));
    for (int i = 0; i < maxPrefix; i++) {
      if (s1[i] == s2[i]) {
        prefixLen++;
      } else {
        break;
      }
    }

    return jaro + (prefixLen * 0.1 * (1.0 - jaro));
  }
}
