from flask import Flask, request, jsonify
from chat_engine import chat_with_model

app = Flask(__name__)

@app.route('/chat', methods=['POST'])
def chat():
    user_prompt = request.json.get("prompt")
    reply = chat_with_model(user_prompt)
    return jsonify({"response": reply})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
