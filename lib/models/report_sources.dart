const reportExtensions = ['pdf', 'xlsx', 'xls', 'csv', 'ofx', 'json', 'tsv'];

String monthLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}';

class ReportSource {
  const ReportSource(
    this.company,
    this.address,
    this.extension, {
    this.ticker = '',
  });
  final String company, address, extension, ticker;

  factory ReportSource.fromJson(Map<String, dynamic> json) => ReportSource(
    json['company'] as String,
    json['address'] as String,
    json['extension'] as String,
    ticker: json['ticker'] as String? ?? '',
  );

  Map<String, String> toJson() => {
    'company': company,
    'address': address,
    'extension': extension,
    'ticker': ticker,
  };

  Uri uriFor(DateTime date) {
    final uri = Uri.tryParse(
      address
          .replaceAll('{ano}', '${date.year}')
          .replaceAll('{mes}', date.month.toString().padLeft(2, '0')),
    );
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.toString().contains('%7B')) {
      throw const FormatException(
        'Informe um link HTTPS direto para o arquivo.',
      );
    }
    return uri;
  }

  Iterable<({Uri uri, String? period})> reports(
    DateTime start,
    DateTime end,
  ) sync* {
    if (!address.contains('{ano}') && !address.contains('{mes}')) {
      yield (uri: uriFor(end), period: null);
      return;
    }
    final monthly = address.contains('{mes}');
    if (monthly && !address.contains('{ano}')) {
      throw const FormatException(
        'Use {ano} junto de {mes} no endereço mensal.',
      );
    }
    var cursor = DateTime(start.year, monthly ? start.month : 1);
    while (!cursor.isAfter(end)) {
      yield (
        uri: uriFor(cursor),
        period: monthly ? monthLabel(cursor) : '${cursor.year}',
      );
      cursor = monthly
          ? DateTime(cursor.year, cursor.month + 1)
          : DateTime(cursor.year + 1);
    }
  }
}
