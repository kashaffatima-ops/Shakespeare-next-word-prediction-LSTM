# flask_api.py

from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import pickle
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.sequence import pad_sequences

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

class ShakespearePredictor:
    def __init__(self):
        """Load model and preprocessing artifacts"""
        try:
            self.model = load_model('shakespeare_lstm_final.h5')
            
            with open('tokenizer.pickle', 'rb') as f:
                self.tokenizer = pickle.load(f)
            
            with open('config.pickle', 'rb') as f:
                config = pickle.load(f)
                self.max_seq_length = config['max_sequence_length']
                self.vocab_size = config['vocab_size']
            
            print("Model loaded successfully!")
        except Exception as e:
            print(f"Error loading model: {e}")
            raise
    
    def predict_next_words(self, input_text, top_k=5, temperature=1.0):
        """Predict next words given input text"""
        input_text = input_text.lower().strip()
        
        if not input_text:
            return []
        
        sequence = self.tokenizer.texts_to_sequences([input_text])[0]
        
        if len(sequence) == 0:
            return []
        
        if len(sequence) > self.max_seq_length:
            sequence = sequence[-self.max_seq_length:]
        
        padded_sequence = pad_sequences([sequence], 
                                       maxlen=self.max_seq_length, 
                                       padding='pre')
        
        predictions = self.model.predict(padded_sequence, verbose=0)[0]
        
        # Apply temperature
        predictions = np.log(predictions + 1e-10) / temperature
        predictions = np.exp(predictions)
        predictions = predictions / np.sum(predictions)
        
        # Get top k predictions
        top_indices = np.argsort(predictions)[-top_k:][::-1]
        
        index_to_word = {v: k for k, v in self.tokenizer.word_index.items()}
        
        results = []
        for idx in top_indices:
            if idx > 0 and idx in index_to_word:
                word = index_to_word[idx]
                prob = predictions[idx]
                results.append({
                    'word': word,
                    'probability': float(prob)
                })
        
        return results

# Initialize predictor
predictor = ShakespearePredictor()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_loaded': predictor.model is not None
    })

@app.route('/predict', methods=['POST'])
def predict():
    """
    Predict next words
    
    Request body:
    {
        "text": "to be or",
        "top_k": 5,
        "temperature": 1.0
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'text' not in data:
            return jsonify({
                'error': 'Missing text field'
            }), 400
        
        text = data['text']
        top_k = data.get('top_k', 5)
        temperature = data.get('temperature', 1.0)
        
        predictions = predictor.predict_next_words(text, top_k, temperature)
        
        return jsonify({
            'input_text': text,
            'predictions': predictions
        })
    
    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

@app.route('/generate', methods=['POST'])
def generate():
    """
    Generate complete sentence
    
    Request body:
    {
        "seed_text": "to be",
        "num_words": 20,
        "temperature": 0.7
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'seed_text' not in data:
            return jsonify({
                'error': 'Missing seed_text field'
            }), 400
        
        seed_text = data['seed_text']
        num_words = data.get('num_words', 20)
        temperature = data.get('temperature', 0.7)
        
        current_text = seed_text.lower().strip()
        
        for _ in range(num_words):
            predictions = predictor.predict_next_words(current_text, 
                                                      top_k=10, 
                                                      temperature=temperature)
            
            if not predictions:
                break
            
            words = [p['word'] for p in predictions]
            probs = np.array([p['probability'] for p in predictions])
            probs = probs / probs.sum()
            
            next_word = np.random.choice(words, p=probs)
            current_text += " " + next_word
        
        return jsonify({
            'seed_text': seed_text,
            'generated_text': current_text
        })
    
    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

if __name__ == '__main__':
    print("=" * 60)
    print("Shakespeare LSTM API Server")
    print("=" * 60)
    print("\nStarting server on http://localhost:5000")
    print("\nEndpoints:")
    print("  GET  /health  - Check server health")
    print("  POST /predict - Get word predictions")
    print("  POST /generate - Generate sentence")
    print("\n" + "=" * 60)
    
    app.run(host='0.0.0.0', port=5000, debug=True)