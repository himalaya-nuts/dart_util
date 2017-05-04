library punycode;

class PunycodeException {
  String message;

  static const INVALID_INPUT = 'Invalid input';
  static const OVERFLOW      = 'Overflow: input needs wider integers to process';
  static const NOT_BASIC     = 'Illegal input >= 0x80 (not a basic code point)';

  PunycodeException(this.message);

  @override
  String toString() {
    return 'PunycodeException{message: $message}';
  }
}

final converter = new Punycode();

String decode(String value) => converter.decode(value);
String encode(String value) => converter.encode(value);

String urlDecode(String value) => converter.urlDecode(value);
String urlEncode(String value) => converter.urlEncode(value);
/**
 * Implementation of IDNA - RFC 3490 standard converter
 * http://www.rfc-base.org/rfc-3490.html
 *
 * */
class Punycode {

  /* constants */
  static const int base = 36;
  static const int tMin = 1;
  static const int tMax = 26;

  static const int skew = 38;
  static const int damp = 700;

  static const int initialBias = 72;
  static const int initialN = 128; // 0x80
  static const delimiter = '-'; // '\x2D'

  /** Highest positive signed 32-bit float value */
  static const maxInt = 2147483647; // aka. 0x7FFFFFFF or 2^31-1

  /** Regular expressions */
  static RegExp regexPunycode   = new RegExp(r'^xn--');
  static RegExp regexNonASCII   = new RegExp(r'[^\0-\x7E]'); // non-ASCII chars
  static RegExp regexSeparators = new RegExp(r'[\u002E\u3002\uFF0E\uFF61]'); // RFC 3490 separators
  static RegExp regexUrlprefix  = new RegExp(r'^http://|^https://');
  /**
   * Converts a string of Unicode symbols (e.g. a domain name label) to a
   * Punycode string of ASCII-only symbols.
   * @param {String} input The string of Unicode symbols.
   * @returns {String} The resulting Punycode string of ASCII-only symbols.
   */
  String encode(String input) {
    int n = initialN;
    int delta = 0;
    int bias = initialBias;
    List<int> output = [];

    // Copy all basic code points to the output
    int b = 0;
    for (int i = 0; i < input.length; i++) {
      int c = input.codeUnitAt(i);
      if (isBasic(c)) {
        output.add(c);
        b++;
      }
    }

    // Append delimiter
    if (b > 0) {
      output.add(delimiter.codeUnitAt(0));
    }

    int h = b;
    while (h < input.length) {
      int m = maxInt;

      // Find the minimum code point >= n
      for (int i = 0; i < input.length; i++) {
        int c = input.codeUnitAt(i);
        if (c >= n && c < m) {
          m = c;
        }
      }

      if (m - n > (maxInt - delta) / (h + 1)) {
        throw new PunycodeException(PunycodeException.OVERFLOW);
      }
      delta = delta + (m - n) * (h + 1);
      n = m;

      for (int j = 0; j < input.length; j++) {
        int c = input.codeUnitAt(j);
        if (c < n) {
          delta++;
          if (0 == delta) {
            throw new PunycodeException(PunycodeException.OVERFLOW);
          }
        }
        if (c == n) {
          int q = delta;

          for (int k = base;; k += base) {
            int t;
            if (k <= bias) {
              t = tMin;
            } else if (k >= bias + tMax) {
              t = tMax;
            } else {
              t = k - bias;
            }
            if (q < t) {
              break;
            }
            output.add((digitToBasic(t + (q - t) % (base - t))));
            q = ((q - t) / (base - t)).floor();
          }

          output.add(digitToBasic(q));
          bias = adapt(delta, h + 1, h == b);
          delta = 0;
          h++;
        }
      }

      delta++;
      n++;
    }

    return new String.fromCharCodes(output);
  }

  /**
   * Decode a punycoded string.
   *
   * @param input Punycode string
   * @return Unicode string.
   */
  String decode(String input) {
    int n = initialN;
    int i = 0;
    int bias = initialBias;
    List<int> output = [];

    int d = input.lastIndexOf(delimiter);
    if (d > 0) {
      for (int j = 0; j < d; j++) {
        int c = input.codeUnitAt(j);
        if (!isBasic(c)) {
          throw new PunycodeException(PunycodeException.INVALID_INPUT);
        }
        output.add(c);
      }
      d++;
    } else {
      d = 0;
    }

    while (d < input.length) {
      int oldi = i;
      int w = 1;

      for (int k = base;; k += base) {
        if (d == input.length) {
          throw new PunycodeException(PunycodeException.INVALID_INPUT);
        }
        int c = input.codeUnitAt(d++);
        int digit = basicToDigit(c);
        if (digit > (maxInt - i) / w) {
          throw new PunycodeException(PunycodeException.OVERFLOW);
        }

        i = i + digit * w;

        int t;
        if (k <= bias) {
          t = tMin;
        } else if (k >= bias + tMax) {
          t = tMax;
        } else {
          t = k - bias;
        }
        if (digit < t) {
          break;
        }
        w = w * (base - t);
      }

      bias = adapt(i - oldi, output.length + 1, oldi == 0);

      if (i / (output.length + 1) > maxInt - n) {
        throw new PunycodeException(PunycodeException.OVERFLOW);
      }

      n = (n + i / (output.length + 1)).floor();
      i = i % (output.length + 1);
      output.insert(i, n);
      i++;
    }

    return new String.fromCharCodes(output);
  }

  int adapt(int delta, int numpoints, bool first) {
    if (first) {
      delta = (delta / damp).floor();
    } else {
      delta = (delta / 2).floor();
    }

    delta = delta + (delta / numpoints).floor();

    int k = 0;
    while (delta > ((base - tMin) * tMax) / 2) {
      delta = (delta / (base - tMin)).floor();
      k = k + base;
    }

    return (k + ((base - tMin + 1) * delta) / (delta + skew)).floor();
  }

  /**
   * Validate if value is within ASCII set
   */
  bool isBasic(int c) {
    return c < 0x80;
  }

  /**
   * Converts a digit/integer into a basic code point.
   * @see `basicToDigit()`
   * @private
   * @param {Number} digit The numeric value of a basic code point.
   * @returns {Number} The basic code point whose value
   */
  int digitToBasic(int digit) {
    if (digit < 26) {
      // 0..25 : 'a'..'z'
      return digit + 'a'.codeUnitAt(0);
    } else if (digit < 36) {
      // 26..35 : '0'..'9';
      return digit - 26 + '0'.codeUnitAt(0);
    } else {
      throw new PunycodeException(PunycodeException.INVALID_INPUT);
    }
  }

  /**
   * Converts a basic code point into a digit/integer.
   * @see `digitToBasic()`
   * @private
   * @param {Number} codePoint The basic numeric code point value.
   * @returns {Number} The numeric value of a basic code point (for use in
   * representing integers) in the range `0` to `base - 1`, or `base` if
   * the code point does not represent a value.
   */
  int basicToDigit(int codePoint) {
    if (codePoint - '0'.codeUnitAt(0) < 10) {
      // '0'..'9' : 26..35
      return codePoint - '0'.codeUnitAt(0) + 26;
    } else if (codePoint - 'a'.codeUnitAt(0) < 26) {
      // 'a'..'z' : 0..25
      return codePoint - 'a'.codeUnitAt(0);
    } else {
      throw new PunycodeException(PunycodeException.INVALID_INPUT);
    }
  }


  String urlDecode(String value){
    return _urlConvert(value , false);
  }

  String urlEncode(String value) {
    return _urlConvert(value , true);
  }

  String _urlConvert(String url , bool shouldencode) {

    List<String> _url    = new List();
    List<String> _result = new List();
    if (regexUrlprefix.hasMatch(url)) {
      _url = url.split('/');
    } else {
      _url.add(url);
    }
    _url.forEach((String _suburl) {

      _suburl = _suburl.replaceAll(regexSeparators, '\x2E');

      List<String> _split = _suburl.split('.');

      List<String> _join = new List();

      _split.forEach((elem){
        // do decode and encode
        if(shouldencode) {
          if (regexPunycode.hasMatch(elem) || regexNonASCII.hasMatch(elem) == false) {
            _join.add(elem);
          } else {
            _join.add('xn--' + encode(elem));
          }
        }else{
          if (regexNonASCII.hasMatch(elem)) {
            throw new PunycodeException(PunycodeException.NOT_BASIC);
          } else {
            _join.add(regexPunycode.hasMatch(elem)?decode(elem.replaceFirst(regexPunycode, '')):elem);
          }

        }

      });
      _result.add(_join.length > 0 ?_join.join('.'):_suburl);
    });

    return _result.length > 1 ? _result.join('/'): _result.length==1?_result.elementAt(0):null;

  }
}
