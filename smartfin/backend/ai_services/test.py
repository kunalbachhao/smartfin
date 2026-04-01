import requests
import json

# FastAPI endpoint
url = "http://127.0.0.1:8000/predict"

# Example SMS messages to test
test_messages = [
    "Your account has been credited with Rs. 5000",
    "You spent Rs. 1200 at Amazon",
    "Rs. 3500 withdrawn from A/c XXXX1234",
]

for sms in test_messages:
    data = {"sms": sms}
    try:
        resp = requests.post(url, json=data)
        result = resp.json()
        print("\n===== SMS =====")
        print(f"Message: {sms}")
        print("Prediction:")
        print(json.dumps(result, indent=4))  # <-- Pretty print here
    except Exception as e:
        print(f"Failed to classify SMS: {e}")