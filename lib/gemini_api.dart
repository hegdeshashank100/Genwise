import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:pem/pem.dart';

class GeminiApi {
  GeminiApi._();

  // Gemini API config (for text generation)
  static const _baseUrl = 'https://generativelanguage.googleapis.com';
  static const _version = 'v1beta';
  static const _textModel = 'models/gemini-2.0-flash';
  static const String apiKey = 'YOUR_API_KEY_HERE';

  /// TEXT GENERATION (API Key based, still available)
  static Future<String> callGemini({
    required String prompt,
    String endpoint = '',
  }) async {
    try {
      final url = '$_baseUrl/$_version/$_textModel:generateContent?key=$apiKey';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] ?? 'No text generated';
          }
        }
        return 'No valid response generated';
      } else {
        throw Exception(
          'Gemini API error: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error calling Gemini API: $e');
    }
  }

  /// IMAGE GENERATION (Imagen 2 via Vertex AI, uses Service Account JSON)
  static Future<String> generateImage({
    required String prompt,
    File? logoFile,
  }) async {
    try {
      // Load updated service account JSON
      final serviceAccountJson = await rootBundle.loadString(
        'assets/true-elevator-451713-h5-61c14c2cd65a.json',
      );
      final serviceAccount = jsonDecode(serviceAccountJson);

      final clientEmail = serviceAccount['client_email'];
      final privateKeyPem = serviceAccount['private_key'];

      // Create JWT
      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = iat + 3600;
      final header = {'alg': 'RS256', 'typ': 'JWT'};
      final payload = {
        'iss': clientEmail,
        'scope': 'https://www.googleapis.com/auth/cloud-platform',
        'aud': 'https://oauth2.googleapis.com/token',
        'exp': exp,
        'iat': iat,
      };

      String base64UrlEncode(List<int> bytes) =>
          base64Url.encode(bytes).replaceAll('=', '');

      final jwtHeader = base64UrlEncode(utf8.encode(jsonEncode(header)));
      final jwtPayload = base64UrlEncode(utf8.encode(jsonEncode(payload)));
      final signingInput = '$jwtHeader.$jwtPayload';

      // Sign with RS256
      final signer = RS256Signer(privateKeyPem);
      final signatureBytes = await signer.sign(utf8.encode(signingInput));
      final signature = base64UrlEncode(signatureBytes);

      final jwt = '$signingInput.$signature';

      // Get OAuth access token
      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': jwt,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Failed to get access token: ${tokenResponse.body}');
      }
      final accessToken = jsonDecode(tokenResponse.body)['access_token'];

      // Call Imagen 2 API
      const projectId = 'true-elevator-451713';
      const location = 'us-central1';
      const modelId = 'publishers/google/models/imagegeneration';

      String? logoBase64;
      if (logoFile != null) {
        logoBase64 = base64Encode(await logoFile.readAsBytes());
      }

      final url =
          'https://$location-aiplatform.googleapis.com/v1/projects/$projectId/locations/$location/$modelId:predict';

      final Map<String, dynamic> body = {
        "instances": [
          {
            "prompt": prompt,
            if (logoBase64 != null) "image": {"bytesBase64Encoded": logoBase64},
          },
        ],
        "parameters": {
          "sampleCount": 1,
          "width": 1080,
          "height": 1350,
          "outputMimeType": "image/png",
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['predictions'] != null &&
            data['predictions'][0]['bytesBase64Encoded'] != null) {
          return data['predictions'][0]['bytesBase64Encoded'];
        }
        throw Exception('No image data in API response');
      } else {
        throw Exception(
          'Imagen 2 API error: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error generating image: $e');
    }
  }
}

/// RSA SHA256 Signer for JWT
class RS256Signer {
  final String privateKeyPem;
  RS256Signer(this.privateKeyPem);

  Future<List<int>> sign(List<int> data) async {
    final keyBytes = PemCodec(PemLabel.privateKey).decode(privateKeyPem);
    final algorithm = RsaPss(Sha256());
    final keyPair = await algorithm.newKeyPairFromSeed(
      Uint8List.fromList(keyBytes.sublist(keyBytes.length - 32)),
    ); // 32 bytes seed
    final signature = await algorithm.sign(data, keyPair: keyPair);
    return signature.bytes;
  }
}
