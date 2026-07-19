from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def home():
    # Safely checks system memory for the environment mode instead of hardcoding
    env_status = os.environ.get("ENV_MODE", "Development")
    return f"🚀 Secure Bank App Instance Online | Mode: {env_status}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)