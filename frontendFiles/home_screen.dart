import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();

  List<Prediction> _predictions = [];
  bool _isLoading = false;
  bool _isConnected = false;
  String _errorMessage = '';
  Timer? _debounceTimer;

  // Hyperparameters
  int _topK = 5;
  double _temperature = 1.0;

  String _generatedText = '';
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final isHealthy = await _apiService.checkHealth();
      setState(() {
        _isConnected = isHealthy;
        _isLoading = false;
        if (!isHealthy) {
          _errorMessage =
              'Unable to connect to the server. Please ensure the Flask API is running.';
        }
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _onTextChanged() {
    // Debounce: wait 500ms after user stops typing
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final text = _textController.text.trim();
      if (text.isNotEmpty) {
        _getPredictions(text);
      } else {
        setState(() {
          _predictions = [];
        });
      }
    });
  }

  Future<void> _getPredictions(String text) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final predictions = await _apiService.predictNextWords(
        text: text,
        topK: _topK,
        temperature: _temperature,
      );

      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error getting predictions: $e';
        _predictions = [];
      });
    }
  }

  void _onWordSelected(String word) {
    final currentText = _textController.text;
    _textController.text = '$currentText $word';
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  Future<void> _generateSentence() async {
    final seedText = _textController.text.trim();
    if (seedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text first')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = '';
    });

    try {
      final generated = await _apiService.generateSentence(
        seedText: seedText,
        numWords: 20,
        temperature: _temperature,
      );

      setState(() {
        _generatedText = generated;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = 'Error generating sentence: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shakespeare Word Predictor'),
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _checkConnection,
            tooltip: _isConnected ? 'Connected' : 'Disconnected',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            if (!_isConnected)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage.isEmpty
                              ? 'Not connected to server'
                              : _errorMessage,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkConnection,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Text Input Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Text',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Start typing... e.g., "to be or"',
                        border: OutlineInputBorder(),
                      ),
                      enabled: _isConnected,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isConnected && !_isGenerating
                                ? _generateSentence
                                : null,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('Generate Sentence'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            _textController.clear();
                            setState(() {
                              _predictions = [];
                              _generatedText = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hyperparameters Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hyperparameters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Top K: '),
                        Expanded(
                          child: Slider(
                            value: _topK.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _topK.toString(),
                            onChanged: (value) {
                              setState(() {
                                _topK = value.toInt();
                              });
                              if (_textController.text.isNotEmpty) {
                                _getPredictions(_textController.text);
                              }
                            },
                          ),
                        ),
                        Text(_topK.toString()),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Temperature: '),
                        Expanded(
                          child: Slider(
                            value: _temperature,
                            min: 0.1,
                            max: 2.0,
                            divisions: 19,
                            label: _temperature.toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() {
                                _temperature = value;
                              });
                              if (_textController.text.isNotEmpty) {
                                _getPredictions(_textController.text);
                              }
                            },
                          ),
                        ),
                        Text(_temperature.toStringAsFixed(1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Temperature controls randomness:\n'
                      '• Lower (0.5) = More conservative, predictable\n'
                      '• Higher (1.5) = More creative, random',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Predictions Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Next Word Predictions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_predictions.isEmpty && !_isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Start typing to see predictions...',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _predictions.map((prediction) {
                          return InkWell(
                            onTap: () => _onWordSelected(prediction.word),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.deepPurple.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      prediction.word,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${(prediction.probability * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepPurple.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.touch_app,
                                    size: 16,
                                    color: Colors.deepPurple.shade400,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // Generated Sentence Card
            if (_generatedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome,
                              color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Generated Sentence',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _generatedText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
