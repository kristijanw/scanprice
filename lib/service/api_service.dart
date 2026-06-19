import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String _model = 'gpt-4o-mini';

  Future<String> sendImage(File imageFile) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

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
      "model": _model,
      "response_format": {"type": "json_object"},
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
            },
          ],
        },
      ],
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final text = data['choices'][0]['message']['content'] as String;
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
