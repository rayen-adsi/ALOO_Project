import re
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# ===================== VALIDATION HELPERS =====================

def is_valid_email(email):
    return re.match(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$', email)

def is_valid_password(password):
    if len(password) < 8:
        return False, "Password must be at least 8 characters"
    if not re.search(r'[A-Z]', password):
        return False, "Password must contain at least one uppercase letter"
    if not re.search(r'[a-z]', password):
        return False, "Password must contain at least one lowercase letter"
    if not re.search(r'[0-9]', password):
        return False, "Password must contain at least one number"
    if not re.search(r'[!@#$%^&*(),.?\":{}|<>]', password):
        return False, "Password must contain at least one special character"
    return True, ""

def is_valid_phone(phone):
    return re.match(r'^\+?[0-9]{8,15}$', phone)

VALID_CATEGORIES = [
    "Plombier", "Électricien", "Mécanicien",
    "Femme de ménage", "Professeur", "Développeur"
]

# ===================== ROUTES =====================

@app.route("/ping")
def ping():
    return jsonify({"message": "Backend connected"})

@app.route("/auth/login", methods=["POST"])
def login():
    data = request.json
    email = data.get("email", "").strip()
    password = data.get("password", "")

    if not email or not password:
        return jsonify({"success": False, "message": "Please fill all fields"}), 400

    if not is_valid_email(email):
        return jsonify({"success": False, "message": "Enter a valid email address"}), 400

    valid, msg = is_valid_password(password)
    if not valid:
        return jsonify({"success": False, "message": msg}), 400

    return jsonify({"success": True, "message": "Login successful"})


@app.route("/auth/signup/client", methods=["POST"])
def signup_client():
    data = request.json

    full_name = data.get("full_name", "").strip()
    email     = data.get("email", "").strip()
    phone     = data.get("phone", "").strip()
    password  = data.get("password", "")
    password2 = data.get("password2", "")
    address   = data.get("address", "").strip()

    # Empty checks
    if not all([full_name, email, phone, password, password2, address]):
        return jsonify({"success": False, "message": "Please fill all fields"}), 400

    # Full name
    if len(full_name) < 3:
        return jsonify({"success": False, "message": "Full name must be at least 3 characters"}), 400

    # Email
    if not is_valid_email(email):
        return jsonify({"success": False, "message": "Enter a valid email address"}), 400

    # Phone
    if not is_valid_phone(phone):
        return jsonify({"success": False, "message": "Enter a valid phone number"}), 400

    # Password
    valid, msg = is_valid_password(password)
    if not valid:
        return jsonify({"success": False, "message": msg}), 400

    # Confirm password
    if password != password2:
        return jsonify({"success": False, "message": "Passwords do not match"}), 400

    # Address
    if len(address) < 5:
        return jsonify({"success": False, "message": "Enter a valid address"}), 400

    # TODO: save client to database

    return jsonify({"success": True, "message": "Client account created successfully"})


@app.route("/auth/signup/provider/step1", methods=["POST"])
def signup_provider_step1():
    data = request.json

    full_name = data.get("full_name", "").strip()
    email     = data.get("email", "").strip()
    phone     = data.get("phone", "").strip()
    password  = data.get("password", "")
    password2 = data.get("password2", "")

    # Empty checks
    if not all([full_name, email, phone, password, password2]):
        return jsonify({"success": False, "message": "Please fill all fields"}), 400

    # Full name
    if len(full_name) < 3:
        return jsonify({"success": False, "message": "Full name must be at least 3 characters"}), 400

    # Email
    if not is_valid_email(email):
        return jsonify({"success": False, "message": "Enter a valid email address"}), 400

    # Phone
    if not is_valid_phone(phone):
        return jsonify({"success": False, "message": "Enter a valid phone number"}), 400

    # Password
    valid, msg = is_valid_password(password)
    if not valid:
        return jsonify({"success": False, "message": msg}), 400

    # Confirm password
    if password != password2:
        return jsonify({"success": False, "message": "Passwords do not match"}), 400

    return jsonify({"success": True, "message": "Step 1 validated"})


@app.route("/auth/signup/provider/step2", methods=["POST"])
def signup_provider_step2():
    data = request.json

    category = data.get("category", "").strip()
    city     = data.get("city", "").strip()
    address  = data.get("address", "").strip()
    bio      = data.get("bio", "").strip()

    # Empty checks
    if not all([category, city, address, bio]):
        return jsonify({"success": False, "message": "Please fill all fields"}), 400

    # Category
    if category not in VALID_CATEGORIES:
        return jsonify({"success": False, "message": "Select a valid category"}), 400

    # City
    if len(city) < 2:
        return jsonify({"success": False, "message": "Enter a valid city"}), 400

    # Address
    if len(address) < 5:
        return jsonify({"success": False, "message": "Enter a valid address"}), 400

    # Bio
    if len(bio) < 10:
        return jsonify({"success": False, "message": "Bio must be at least 10 characters"}), 400

    # TODO: save provider to database (combine step1 + step2 data)

    return jsonify({"success": True, "message": "Provider account created successfully"})


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)