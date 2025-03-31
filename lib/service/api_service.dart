import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiAIService {
  final String _apiKey = 'AIzaSyB8uxO_IytG-4wFjDjB-VglJjdUEX-1TJ0'; // Paziti da nije izložen!

  Future<String> sendImage(File imageFile) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$_apiKey');

    final prompt = '''
Pregledaj sliku i izvuci mi sljedeće podatke:

Naziv proizvoda,
Cijenu proizvoda,
Akcijsku cijenu ako postoji,
Provjeru je li potrebna kartica za pogodnosti.

Sve te informacije mi vrati u JSON formatu bez dodatnog teksta, objašnjenja i bez markdown oznaka kao što su ```.

Očekivana JSON struktura:

{
  "title": "Naziv proizvoda",
  "price": 0.0,
  "price_discount": 0.0,
  "card": false
}
''';

    // Pretvaranje slike u base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inlineData": {
                "mimeType": "image/jpeg", // ili image/png ako je PNG
                "data": base64Image,
              },
            },
          ],
        },
      ],
    });

    final headers = {'Content-Type': 'application/json'};

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Pristupi odgovoru ovisno o strukturi
        final candidates = data['candidates'] as List?;
        final content = candidates?.first['content'];
        final parts = content['parts'] as List?;
        final text = parts?.first['text'];

        print(text);

        return text ?? 'No content in response';
      } else {
        throw Exception('Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error while sending image: $e');
    }
  }
}
