import re
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_bcrypt import Bcrypt
from datetime import datetime

app = Flask(__name__)
CORS(app)

# ===================== DATABASE CONFIG =====================

app.config["SQLALCHEMY_DATABASE_URI"] = "postgresql://aloo_user:aloo1234@localhost/aloo_db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db      = SQLAlchemy(app)
migrate = Migrate(app, db)
bcrypt  = Bcrypt(app)

# ===================== MODELS =====================

class Client(db.Model):
    __tablename__ = "clients"

    id         = db.Column(db.Integer, primary_key=True)
    full_name  = db.Column(db.String(100), nullable=False)
    email      = db.Column(db.String(120), unique=True, nullable=False)
    phone      = db.Column(db.String(20), nullable=False)
    password   = db.Column(db.String(255), nullable=False)
    address    = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<Client {self.email}>"


class Provider(db.Model):
    __tablename__ = "providers"

    id         = db.Column(db.Integer, primary_key=True)
    full_name  = db.Column(db.String(100), nullable=False)
    email      = db.Column(db.String(120), unique=True, nullable=False)
    phone      = db.Column(db.String(20), nullable=False)
    password   = db.Column(db.String(255), nullable=False)
    category   = db.Column(db.String(100), nullable=False)
    city       = db.Column(db.String(100), nullable=False)
    address    = db.Column(db.String(255), nullable=False)
    bio        = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<Provider {self.email}>"


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
    data     = request.json
    email    = data.get("email", "").strip()
    password = data.get("password", "")

    if not email or not password:
        return jsonify({"success": False, "message": "Please fill all fields"}), 400

    if not is_valid_email(email):
        return jsonify({"success": False, "message": "Enter a valid email address"}), 400

    # Check clients first
    user = Client.query.filter_by(email=email).first()
    role = "client"

    # If not found check providers
    if not user:
        user = Provider.query.filter_by(email=email).first()
        role = "provider"

    if not user:
        return jsonify({"success": False, "message": "Email not found"}), 401

    # Verify hashed password
    if not bcrypt.check_password_hash(user.password, password):
        return jsonify({"success": False, "message": "Wrong password"}), 401

    return jsonify({
        "success":   True,
        "message":   "Login successful",
        "role":      role,
        "full_name": user.full_name,
        "email":     user.email,
    })


@app.route("/auth/signup/client", methods=["POST"])
def signup_client():
    data      = request.json
    full_name = data.get("full_name", "").strip()
    email     = data.get("email", "").strip()
    phone     = data.get("phone", "").strip()
    password  = data.get("password", "")
    password2 = data.get("password2", "")
    address   = data.get("address", "").strip()

    if not all([full_name, email, phone, password, password2, address]):
        return jsonify({"success": False, "message": "Please fill all fields"}), 400

    if len(full_name) < 3:
        return jsonify({"success": False, "message": "Full name must be at least 3 characters"}), 400

    if not is_valid_email(email):
        return jsonify({"success": False, "message": "Enter a valid email address"}), 400

    if not is_valid_phone(phone):
        return jsonify({"success": False, "message": "Enter a valid phone number"}), 400

    valid, msg = is_valid_password(password)
    if not valid:
        return jsonify({"success": False, "message": msg}), 400

    if password != password2:
        return jsonify({"success": False, "message": "Passwords do not match"}), 400

    if len(address) < 5:
        return jsonify({"success": False, "message": "Enter a valid address"}), 400

    if Client.query.filter_by(email=email).first():
        return jsonify({"success": False, "message": "Email already registered"}), 409

    # Hash password before saving
    hashed_pw = bcrypt.generate_password_hash(password).decode("utf-8")

    client = Client(
        full_name=full_name,
        email=email,
        phone=phone,
        password=hashed_pw,
        address=address,
    )
    db.session.add(client)
    db.session.commit()

    return jsonify({"success": True, "message": "Client account created successfully"})


@app.route("/auth/signup/provider/step1", methods=["POST"])
def signup_provider_step1():
    data      = request.json
    full_name = data.get("full_name", "").strip()
    email     = data.get("email", "").strip()
    phone     = data.get("phone", "").strip()
    password  = data.get("password", "")
    password2 = data.get("password2", "")

    if not all([full_name, email, phone, password, password2]):
        return jsonify({"success": False, "message": "Please fill all fields"}), 400

    if len(full_name) < 3:
        return jsonify({"success": False, "message": "Full name must be at least 3 characters"}), 400

    if not is_valid_email(email):
        return jsonify({"success": False, "message": "Enter a valid email address"}), 400

    if not is_valid_phone(phone):
        return jsonify({"success": False, "message": "Enter a valid phone number"}), 400

    valid, msg = is_valid_password(password)
    if not valid:
        return jsonify({"success": False, "message": msg}), 400

    if password != password2:
        return jsonify({"success": False, "message": "Passwords do not match"}), 400

    if Provider.query.filter_by(email=email).first():
        return jsonify({"success": False, "message": "Email already registered"}), 409

    return jsonify({"success": True, "message": "Step 1 validated"})


@app.route("/auth/signup/provider/step2", methods=["POST"])
def signup_provider_step2():
    data      = request.json
    full_name = data.get("full_name", "").strip()
    email     = data.get("email", "").strip()
    phone     = data.get("phone", "").strip()
    password  = data.get("password", "")
    category  = data.get("category", "").strip()
    city      = data.get("city", "").strip()
    address   = data.get("address", "").strip()
    bio       = data.get("bio", "").strip()

    if not all([category, city, address, bio]):
        return jsonify({"success": False, "message": "Please fill all fields"}), 400

    if category not in VALID_CATEGORIES:
        return jsonify({"success": False, "message": "Select a valid category"}), 400

    if len(city) < 2:
        return jsonify({"success": False, "message": "Enter a valid city"}), 400

    if len(address) < 5:
        return jsonify({"success": False, "message": "Enter a valid address"}), 400

    if len(bio) < 10:
        return jsonify({"success": False, "message": "Bio must be at least 10 characters"}), 400

    # Hash password before saving
    hashed_pw = bcrypt.generate_password_hash(password).decode("utf-8")

    provider = Provider(
        full_name=full_name,
        email=email,
        phone=phone,
        password=hashed_pw,
        category=category,
        city=city,
        address=address,
        bio=bio,
    )
    db.session.add(provider)
    db.session.commit()

    return jsonify({"success": True, "message": "Provider account created successfully"})


if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(debug=True, host="0.0.0.0", port=5000)