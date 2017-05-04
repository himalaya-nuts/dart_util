# dart_util

A library for Dart developers. Implementing usefull functions not available in Dart language. 

Current Punycode functions adapted from Java Script code [Punycode.js](https://github.com/bestiejs/punycode.js)

## API

### `decode(string)`

Converts a Punycode string of ASCII symbols to a string of Unicode symbols.

### `encode(string)`

Converts a string of Unicode symbols to a Punycode string of ASCII symbols.

### `urlDecode(input)`

Converts a Punycode string representing a domain name to Unicode. Only the Punycoded parts of the input will be converted, i.e. it doesn’t matter if you call it on a string that has already been converted to Unicode.

### `urlEncode(input)`

Converts a Unicode string representing a domain name to Punycode. Only the non-ASCII parts of the input will be converted, i.e. it doesn’t matter if you call it with a domain that’s already in ASCII.


## Usage

A simple usage example:


    import 'package:dart_util/dart_util.dart' as dart_util;

    main() {
        var original = 'http://\u306F\u3058\u3081\u3088\u3046'+'.'+'\u307F\u3093\u306A';

        print('Original Url: $original');

        var encoded = dart_util.urlEncode(original);
        print('Encoded Url: $encoded');

        var decoded = dart_util.urlDecode(encoded);
        print('Decoded Url: $decoded');
    }
    

## License

Dart Utilities is available under the [MIT](https://opensource.org/licenses/mit-license.php) license.


