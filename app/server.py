AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYzKx8192aB1"
from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def home():
    # Safely checks system memory for the environment mode
    env_status = os.environ.get("ENV_MODE", "Development")
    return f"🚀 Secure Bank App Instance Online | Mode: {env_status}"
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
