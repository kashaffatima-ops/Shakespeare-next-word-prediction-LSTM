import 'dart:convert';
import 'package:http/http.dart' as http;

class Prediction {
  final String word;
  final double probability;

  Prediction({required this.word, required this.probability});

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      word: json['word'],
      probability: json['probability'].toDouble(),
    );
  }
}

class ApiService {
  // Desktop/Chrome: http://localhost:5000

  static const String baseUrl = 'http://localhost:5000';

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['model_loaded'] == true;
      }
      return false;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  Future<List<Prediction>> predictNextWords({
    required String text,
    int topK = 5,
    double temperature = 1.0,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'top_k': topK,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = (data['predictions'] as List)
            .map((p) => Prediction.fromJson(p))
            .toList();
        return predictions;
      } else {
        throw Exception('Failed to get predictions: ${response.statusCode}');
      }
    } catch (e) {
      print('Prediction error: $e');
      rethrow;
    }
  }

  Future<String> generateSentence({
    required String seedText,
    int numWords = 20,
    double temperature = 0.7,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'seed_text': seedText,
              'num_words': numWords,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['generated_text'];
      } else {
        throw Exception('Failed to generate sentence: ${response.statusCode}');
      }
    } catch (e) {
      print('Generation error: $e');
      rethrow;
    }
  }
}
