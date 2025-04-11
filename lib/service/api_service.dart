import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiAIService {
  final String _apiKey = 'AIzaSyAJQoaNpZ7uhBvv0wq8HKaT3yV_-Gw5c2g';

  Future<String> sendImage(File imageFile) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$_apiKey');

    final prompt = '''
Analyze the image and extract the following information:

- Product name
- Final price (total amount the customer pays)
- Discounted price, if available
- Whether a loyalty card is required for the discount

Return the information in **pure JSON format** only — no additional explanations, no text, and no markdown formatting like triple backticks.

Expected JSON structure:

{
  "title": "Product name",
  "price": 0.0,
  "price_discount": 0.0,
  "card": false
}
''';

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inlineData": {"mimeType": "image/jpeg", "data": base64Image},
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
        return text ?? 'No content in response';
      } else {
        throw Exception('Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error while sending image: $e');
    }
  }
}
