import 'dart:typed_data';

import 'package:http/http.dart' as http;

Future<Uint8List> fetchReport(Uri uri, int limit) async {
  final client = http.Client();
  try {
    return await (() async {
      final response = await client.send(http.Request('GET', uri));
      if (response.statusCode != 200) {
        throw FormatException(
          'Download indisponível (HTTP ${response.statusCode}).',
        );
      }
      if (response.headers['content-type']?.contains('text/html') == true) {
        throw const FormatException(
          'O endereço retornou uma página. Use o link direto do relatório.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > limit) {
          throw const FormatException(
            'O relatório ultrapassa o limite de importação.',
          );
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    })().timeout(const Duration(seconds: 45));
  } finally {
    client.close();
  }
}
