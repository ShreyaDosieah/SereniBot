from flask import Flask, request, jsonify
from flask_cors import CORS
from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification
from openai import OpenAI
import os
from dotenv import load_dotenv

# Load .env file
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Set up Hugging Face model
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
model_path = os.path.join(BASE_DIR, "finalmodel", "distilbert_sentiment_best")

try:
    model = AutoModelForSequenceClassification.from_pretrained(
        model_path, local_files_only=True
    )
    tokenizer = AutoTokenizer.from_pretrained(
        model_path, local_files_only=True
    )
    sentiment_pipeline = pipeline("text-classification", model=model, tokenizer=tokenizer)
except Exception as e:
    print(f"Error loading Hugging Face model: {e}")
    sentiment_pipeline = None

# Load OpenAI client
openai_api_key = os.getenv("OPENAI_API_KEY")
if not openai_api_key:
    print("❌ OPENAI_API_KEY not found. Make sure it's in your .env file.")
client = OpenAI(api_key=openai_api_key)

@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json()
    user_input = data.get("text", "")

    if not user_input:
        return jsonify({"error": "No input text provided."}), 400

    # Step 1: Get sentiment
    try:
        sentiment_result = sentiment_pipeline(user_input)
        raw_label = sentiment_result[0]["label"]
    except Exception as e:
        print(f"Error in sentiment analysis: {e}")
        return jsonify({"error": "Sentiment analysis failed."}), 500

    sentiment_label = {
        "LABEL_0": "positive",
        "LABEL_1": "neutral",
        "LABEL_2": "negative"
    }.get(raw_label, "neutral")

    # Step 2: Create prompt
    prompt = f"""
You are SereniBot, a compassionate mental health chatbot.
The user seems to be feeling {sentiment_label}.
Respond kindly and empathetically.

User: "{user_input}"
SereniBot:"""

    # Step 3: Get OpenAI response using the new client syntax
    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a supportive mental health chatbot."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.8,
            max_tokens=200
        )
        reply = response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error in OpenAI API call: {e}")
        reply = "Sorry, I'm having trouble responding right now."

    return jsonify({
        "sentiment": sentiment_label,
        "response": reply
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
