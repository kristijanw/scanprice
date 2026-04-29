import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiAIService {
  final String _apiKey = 'AIzaSyDWbm_94hPuUY798yrLJHlXJRRQhaD6zeY';

  Future<String> sendImage(File imageFile) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey',
    );

    const prompt =
        '''Look at this product price tag and extract the following information.
Return ONLY a valid JSON object, nothing else, no explanation.

Format:
{
  "title": "product name and size",
  "price": 0.00,
  "price_discount": null,
  "card": false
}

Rules:
- title: product name with size/weight
- price: regular price as number
- price_discount: discounted price as number, or null if none
- card: true if there is a loyalty card price, false if not''';

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
            },
          ],
        },
      ],
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(text.trim());
        if (match != null) return match.group(0)!;
        throw Exception('Could not parse JSON from response');
      } else {
        throw Exception('Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error while sending image: $e');
    }
  }
}
