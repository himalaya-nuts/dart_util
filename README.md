# dart_util

A library for Dart developers. 

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


