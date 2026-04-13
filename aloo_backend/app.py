# -*- coding: utf-8 -*-
import re
import os
import uuid
import json as _json
from flask import Flask, request, jsonify, send_from_directory, Response
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_bcrypt import Bcrypt
from datetime import datetime
from sqlalchemy import UniqueConstraint

app = Flask(__name__)
CORS(app)

# ===================== DATABASE CONFIG =====================

app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:rayen123@localhost/aloo_db",
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db      = SQLAlchemy(app)
migrate = Migrate(app, db)
bcrypt  = Bcrypt(app)

# ===================== UPLOAD CONFIG =====================

UPLOAD_FOLDER      = 'uploads/profiles'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp'}
MAX_FILE_SIZE      = 5 * 1024 * 1024  # 5 MB

app.config['UPLOAD_FOLDER']      = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_FILE_SIZE

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    return ('.' in filename and
            filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS)

# ===================== SCORING CONSTANTS =====================

NO_SHOW_PENALTY        = 15
COMPLETED_JOB_PTS      = 5
REVIEW_MULTIPLIER      = 2
PROFILE_PHOTO_PTS      = 10
BIO_PTS                = 10
SKILLS_PTS             = 10
PORTFOLIO_PTS          = 10
PROFILE_COMPLETE_BONUS = 10   # one-time bonus for 100% profile

# ===================== MODELS =====================

class Client(db.Model):
    __tablename__ = "clients"
    id            = db.Column(db.Integer, primary_key=True)
    full_name     = db.Column(db.String(100), nullable=False)
    email         = db.Column(db.String(120), unique=True, nullable=False)
    phone         = db.Column(db.String(20), nullable=False)
    password      = db.Column(db.String(255), nullable=False)
    address       = db.Column(db.String(255), nullable=False)
    profile_photo = db.Column(db.Text, nullable=True)
    avatar_index  = db.Column(db.Integer, default=0)
    created_at    = db.Column(db.DateTime, default=datetime.utcnow)


class Provider(db.Model):
    __tablename__       = "providers"
    id                  = db.Column(db.Integer, primary_key=True)
    full_name           = db.Column(db.String(100), nullable=False)
    email               = db.Column(db.String(120), unique=True, nullable=False)
    phone               = db.Column(db.String(20), nullable=False)
    password            = db.Column(db.String(255), nullable=False)
    category            = db.Column(db.String(100), nullable=False)
    city                = db.Column(db.String(100), nullable=False)
    address             = db.Column(db.String(255), nullable=False)
    bio                 = db.Column(db.Text, nullable=False)
    profile_photo       = db.Column(db.Text, nullable=True)
    avatar_index        = db.Column(db.Integer, default=0)
    skills              = db.Column(db.Text, nullable=True)
    portfolio           = db.Column(db.Text, nullable=True)
    rating              = db.Column(db.Float, default=0.0)
    total_reviews       = db.Column(db.Integer, default=0)
    is_verified         = db.Column(db.Boolean, default=False)
    is_active           = db.Column(db.Boolean, default=True)
    score               = db.Column(db.Integer, default=0)
    completed_jobs      = db.Column(db.Integer, default=0)
    profile_bonus_given = db.Column(db.Boolean, default=False)
    created_at          = db.Column(db.DateTime, default=datetime.utcnow)


class Message(db.Model):
    __tablename__  = "messages"
    id             = db.Column(db.Integer, primary_key=True)
    sender_id      = db.Column(db.Integer, nullable=False)
    sender_type    = db.Column(db.String(10), nullable=False)
    receiver_id    = db.Column(db.Integer, nullable=False)
    receiver_type  = db.Column(db.String(10), nullable=False)
    content        = db.Column(db.Text, nullable=False)
    is_read        = db.Column(db.Boolean, default=False)
    created_at     = db.Column(db.DateTime, default=datetime.utcnow)


class Favorite(db.Model):
    __tablename__  = "favorites"
    __table_args__ = (UniqueConstraint("client_id", "provider_id"),)
    id             = db.Column(db.Integer, primary_key=True)
    client_id      = db.Column(db.Integer, nullable=False)
    provider_id    = db.Column(db.Integer, nullable=False)
    created_at     = db.Column(db.DateTime, default=datetime.utcnow)


class Review(db.Model):
    __tablename__ = "reviews"
    id            = db.Column(db.Integer, primary_key=True)
    provider_id   = db.Column(db.Integer, nullable=False)
    client_id     = db.Column(db.Integer, nullable=False)
    rating        = db.Column(db.Float, nullable=False)
    comment       = db.Column(db.Text, nullable=True)
    created_at    = db.Column(db.DateTime, default=datetime.utcnow)


class Notification(db.Model):
    __tablename__ = "notifications"
    id            = db.Column(db.Integer, primary_key=True)
    user_id       = db.Column(db.Integer, nullable=False)
    user_type     = db.Column(db.String(10), nullable=False)
    type          = db.Column(db.String(30), nullable=False)
    message       = db.Column(db.Text, nullable=False)
    is_read       = db.Column(db.Boolean, default=False)
    created_at    = db.Column(db.DateTime, default=datetime.utcnow)


class Report(db.Model):
    __tablename__  = "reports"
    __table_args__ = (
        UniqueConstraint("client_id", "provider_id", "reservation_key"),
    )
    id              = db.Column(db.Integer, primary_key=True)
    client_id       = db.Column(db.Integer, nullable=False)
    provider_id     = db.Column(db.Integer, nullable=False)
    reservation_key = db.Column(db.String(255), nullable=False)
    reason          = db.Column(db.Text, nullable=True)
    points_deducted = db.Column(db.Integer, default=15)
    created_at      = db.Column(db.DateTime, default=datetime.utcnow)

# ===================== HELPERS =====================

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


def ok(data=None, message="Success"):
    return jsonify({"success": True, "message": message, "data": data})


def err(message, code=400):
    return jsonify({"success": False, "message": message, "data": None}), code


def update_provider_rating(provider_id):
    reviews = Review.query.filter_by(provider_id=provider_id).all()
    count   = len(reviews)
    avg     = round(sum(r.rating for r in reviews) / count, 2) if count else 0.0
    p = Provider.query.get(provider_id)
    if p:
        p.rating        = avg
        p.total_reviews = count
        db.session.commit()


def recalc_provider_score(provider_id):
    """
    Score formula:
      Profile photo         : +10 pts
      Bio filled            : +10 pts
      Skills added          : +10 pts
      Portfolio added       : +10 pts  → profile subtotal max = 40
      Profile complete bonus: +10 pts  (one-time, when profile hits 40)
      Per completed job     : +5  pts
      Per review point      : rating * 2 pts
      Per no-show report    : -15 pts
    Score never goes below 0.
    """
    p = Provider.query.get(provider_id)
    if not p:
        return

    # ── Profile score ──────────────────────────────────────
    profile_score = 0
    if p.profile_photo:
        profile_score += PROFILE_PHOTO_PTS
    if p.bio and len(p.bio.strip()) >= 10:
        profile_score += BIO_PTS
    try:
        if _json.loads(p.skills or '[]'):
            profile_score += SKILLS_PTS
    except Exception:
        pass
    try:
        if _json.loads(p.portfolio or '[]'):
            profile_score += PORTFOLIO_PTS
    except Exception:
        pass

    # ── One-time profile completion bonus ──────────────────
    bonus = 0
    if p.profile_bonus_given:
        bonus = PROFILE_COMPLETE_BONUS      # already earned, always include
    elif profile_score >= 40:
        bonus                 = PROFILE_COMPLETE_BONUS
        p.profile_bonus_given = True
        db.session.add(Notification(
            user_id=provider_id, user_type="provider",
            type="profile_complete",
            message=_json.dumps({
                "text": (
                    "\U0001f389 Your profile is 100% complete! "
                    f"You earned +{PROFILE_COMPLETE_BONUS} bonus points."
                ),
                "sender_name":   "ALOO",
                "sender_id":     0,
                "sender_type":   "system",
                "receiver_id":   provider_id,
                "receiver_type": "provider",
                "sender_photo":  None,
                "sender_avatar": 0,
                "bonus_pts":     PROFILE_COMPLETE_BONUS,
            })))

    # ── Performance score ──────────────────────────────────
    performance_score = (p.completed_jobs or 0) * COMPLETED_JOB_PTS

    reviews = Review.query.filter_by(provider_id=provider_id).all()
    for r in reviews:
        performance_score += int(r.rating * REVIEW_MULTIPLIER)

    reports = Report.query.filter_by(provider_id=provider_id).all()
    for rep in reports:
        performance_score -= rep.points_deducted

    p.score = max(0, profile_score + bonus + performance_score)
    db.session.commit()


def _provider_summary(p):
    return {
        "id":                  p.id,
        "full_name":           p.full_name,
        "category":            p.category,
        "city":                p.city,
        "bio":                 p.bio,
        "rating":              p.rating,
        "total_reviews":       p.total_reviews,
        "is_verified":         p.is_verified,
        "profile_photo":       p.profile_photo,
        "avatar_index":        p.avatar_index or 0,
        "score":               p.score or 0,
        "completed_jobs":      p.completed_jobs or 0,
        "profile_bonus_given": p.profile_bonus_given or False,
    }


def _build_notif_payload(sender_type, sender_id, receiver_type, receiver_id,
                         text, notif_type, extra=None):
    sender_obj    = None
    sender_name   = "Unknown"
    sender_photo  = None
    sender_avatar = 0

    if sender_type == "client":
        sender_obj = Client.query.get(sender_id)
    elif sender_type == "provider":
        sender_obj = Provider.query.get(sender_id)

    if sender_obj:
        sender_name   = sender_obj.full_name
        sender_photo  = sender_obj.profile_photo
        sender_avatar = sender_obj.avatar_index or 0

    payload = {
        "text":          text.replace("{name}", sender_name),
        "sender_name":   sender_name,
        "sender_id":     sender_id,
        "sender_type":   sender_type,
        "receiver_id":   receiver_id,
        "receiver_type": receiver_type,
        "sender_photo":  sender_photo,
        "sender_avatar": sender_avatar,
    }
    if extra:
        payload.update(extra)
    return _json.dumps(payload)


VALID_CATEGORIES = [
    "Plombier", "Electricien", "Mecanicien",
    "Femme de menage", "Professeur", "Developpeur", "Reparation domicile"
]

# ===================== PING =====================

@app.route("/ping")
def ping():
    return ok(message="Backend connected")

# ===================== PHOTO UPLOAD =====================

@app.route('/upload/profile-photo', methods=['POST'])
def upload_profile_photo():
    if 'file' not in request.files:
        return err('No file provided')

    file    = request.files['file']
    user_id = request.form.get('user_id', type=int)
    role    = request.form.get('role', 'client')

    if not file or file.filename == '':
        return err('No file selected')
    if not allowed_file(file.filename):
        return err('File type not allowed. Use JPG, PNG or WEBP')
    if not user_id:
        return err('user_id is required')

    ext      = file.filename.rsplit('.', 1)[1].lower()
    filename = f"{role}_{user_id}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)

    for f in os.listdir(app.config['UPLOAD_FOLDER']):
        if f.startswith(f"{role}_{user_id}_"):
            try:
                os.remove(os.path.join(app.config['UPLOAD_FOLDER'], f))
            except Exception:
                pass

    file.save(filepath)
    photo_url = f"http://192.168.0.184:5000/uploads/profiles/{filename}"

    if role == 'client':
        c = Client.query.get(user_id)
        if c:
            c.profile_photo = photo_url
            db.session.commit()
    else:
        p = Provider.query.get(user_id)
        if p:
            p.profile_photo = photo_url
            db.session.commit()
        recalc_provider_score(user_id)

    return ok({'photo_url': photo_url}, 'Photo uploaded successfully')


@app.route('/uploads/profiles/<filename>')
def serve_photo(filename):
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if not os.path.exists(filepath):
        return err('File not found', 404)

    ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
    mime_map = {
        'mp4':  'video/mp4',        'mov': 'video/quicktime',
        'avi':  'video/x-msvideo',  'mkv': 'video/x-matroska',
        'png':  'image/png',        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',       'webp': 'image/webp',
    }
    mimetype = mime_map.get(ext, 'application/octet-stream')

    if ext in ('mp4', 'mov', 'avi', 'mkv'):
        file_size    = os.path.getsize(filepath)
        range_header = request.headers.get('Range')
        if range_header:
            byte_start  = 0
            byte_end    = file_size - 1
            range_match = re.match(r'bytes=(\d+)-(\d*)', range_header)
            if range_match:
                byte_start = int(range_match.group(1))
                if range_match.group(2):
                    byte_end = int(range_match.group(2))
            content_length = byte_end - byte_start + 1

            def generate():
                with open(filepath, 'rb') as f:
                    f.seek(byte_start)
                    remaining = content_length
                    while remaining > 0:
                        chunk = min(8192, remaining)
                        data  = f.read(chunk)
                        if not data:
                            break
                        remaining -= len(data)
                        yield data

            resp = Response(generate(), status=206, mimetype=mimetype)
            resp.headers['Content-Range']  = (
                f'bytes {byte_start}-{byte_end}/{file_size}')
            resp.headers['Accept-Ranges']  = 'bytes'
            resp.headers['Content-Length'] = str(content_length)
            return resp
        else:
            resp = send_from_directory(
                app.config['UPLOAD_FOLDER'], filename, mimetype=mimetype)
            resp.headers['Accept-Ranges']  = 'bytes'
            resp.headers['Content-Length'] = str(os.path.getsize(filepath))
            return resp

    return send_from_directory(
        app.config['UPLOAD_FOLDER'], filename, mimetype=mimetype)


@app.route('/upload/profile-photo', methods=['DELETE'])
def delete_profile_photo():
    data    = request.json
    user_id = data.get('user_id')
    role    = data.get('role', 'client')

    if not user_id:
        return err('user_id is required')

    for f in os.listdir(app.config['UPLOAD_FOLDER']):
        if f.startswith(f"{role}_{user_id}_"):
            try:
                os.remove(os.path.join(app.config['UPLOAD_FOLDER'], f))
            except Exception:
                pass

    if role == 'client':
        c = Client.query.get(user_id)
        if c:
            c.profile_photo = None
            db.session.commit()
    else:
        p = Provider.query.get(user_id)
        if p:
            p.profile_photo = None
            db.session.commit()
        recalc_provider_score(user_id)

    return ok(message='Photo removed successfully')

# ===================== AUTH =====================

@app.route("/auth/login", methods=["POST"])
def login():
    data     = request.json
    email    = data.get("email", "").strip()
    password = data.get("password", "")

    if not email or not password:
        return err("Please fill all fields")
    if not is_valid_email(email):
        return err("Enter a valid email address")

    user = Client.query.filter_by(email=email).first()
    role = "client"
    if not user:
        user = Provider.query.filter_by(email=email).first()
        role = "provider"
    if not user:
        return err("Email not found", 401)
    if not bcrypt.check_password_hash(user.password, password):
        return err("Wrong password", 401)

    return ok({
        "role":         role,
        "id":           user.id,
        "full_name":    user.full_name,
        "email":        user.email,
        "avatar_index": user.avatar_index or 0,
    }, "Login successful")


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
        return err("Please fill all fields")
    if len(full_name) < 3:
        return err("Full name must be at least 3 characters")
    if not is_valid_email(email):
        return err("Enter a valid email address")
    if not is_valid_phone(phone):
        return err("Enter a valid phone number")
    valid, msg = is_valid_password(password)
    if not valid:
        return err(msg)
    if password != password2:
        return err("Passwords do not match")
    if len(address) < 5:
        return err("Enter a valid address")
    if Client.query.filter_by(email=email).first():
        return err("Email already registered", 409)

    hashed = bcrypt.generate_password_hash(password).decode("utf-8")
    db.session.add(Client(
        full_name=full_name, email=email, phone=phone,
        password=hashed, address=address))
    db.session.commit()
    return ok(message="Client account created successfully")


@app.route("/auth/signup/provider/step1", methods=["POST"])
def signup_provider_step1():
    data      = request.json
    full_name = data.get("full_name", "").strip()
    email     = data.get("email", "").strip()
    phone     = data.get("phone", "").strip()
    password  = data.get("password", "")
    password2 = data.get("password2", "")

    if not all([full_name, email, phone, password, password2]):
        return err("Please fill all fields")
    if len(full_name) < 3:
        return err("Full name must be at least 3 characters")
    if not is_valid_email(email):
        return err("Enter a valid email address")
    if not is_valid_phone(phone):
        return err("Enter a valid phone number")
    valid, msg = is_valid_password(password)
    if not valid:
        return err(msg)
    if password != password2:
        return err("Passwords do not match")
    if Provider.query.filter_by(email=email).first():
        return err("Email already registered", 409)

    return ok(message="Step 1 validated")


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
        return err("Please fill all fields")
    if category not in VALID_CATEGORIES:
        return err("Select a valid category")
    if len(city) < 2:
        return err("Enter a valid city")
    if len(address) < 5:
        return err("Enter a valid address")
    if len(bio) < 10:
        return err("Bio must be at least 10 characters")

    hashed = bcrypt.generate_password_hash(password).decode("utf-8")
    new_p  = Provider(
        full_name=full_name, email=email, phone=phone,
        password=hashed, category=category, city=city,
        address=address, bio=bio)
    db.session.add(new_p)
    db.session.commit()
    recalc_provider_score(new_p.id)
    return ok(message="Provider account created successfully")

# ===================== PROVIDERS =====================

@app.route("/providers", methods=["GET"])
def get_providers():
    providers = (Provider.query
                 .filter_by(is_active=True)
                 .order_by(Provider.score.desc())
                 .all())
    return ok([_provider_summary(p) for p in providers])


@app.route("/providers/search", methods=["GET"])
def search_providers():
    q        = request.args.get("q", "").strip()
    category = request.args.get("category", "").strip()
    city     = request.args.get("city", "").strip()

    query = Provider.query.filter_by(is_active=True)
    if q:
        query = query.filter(Provider.full_name.ilike(f"%{q}%"))
    if category:
        query = query.filter_by(category=category)
    if city:
        query = query.filter_by(city=city)

    return ok([_provider_summary(p)
               for p in query.order_by(Provider.score.desc()).all()])


@app.route("/providers/<int:provider_id>", methods=["GET"])
def get_provider(provider_id):
    p = Provider.query.get(provider_id)
    if not p:
        return err("Provider not found", 404)

    reviews = (Review.query
               .filter_by(provider_id=provider_id)
               .order_by(Review.created_at.desc())
               .all())
    reviews_data = []
    for r in reviews:
        client = Client.query.get(r.client_id)
        reviews_data.append({
            "client_name":   client.full_name if client else "Unknown",
            "client_photo":  client.profile_photo if client else None,
            "client_avatar": client.avatar_index  if client else 0,
            "rating":        r.rating,
            "comment":       r.comment,
            "created_at":    r.created_at.isoformat(),
        })

    return ok({
        **_provider_summary(p),
        "email":     p.email,
        "phone":     p.phone,
        "address":   p.address,
        "is_active": p.is_active,
        "skills":    p.skills,
        "portfolio": p.portfolio,
        "reviews":   reviews_data,
    })


@app.route("/providers/<int:provider_id>", methods=["PUT"])
def update_provider(provider_id):
    p = Provider.query.get(provider_id)
    if not p:
        return err("Provider not found", 404)

    data = request.json
    for field in ("bio", "city", "address", "profile_photo",
                  "is_active", "skills", "portfolio", "avatar_index"):
        if field in data:
            setattr(p, field, data[field])
    db.session.commit()
    recalc_provider_score(provider_id)
    return ok(message="Profile updated successfully")

# ===================== PROVIDER STATS =====================

@app.route("/provider/<int:provider_id>/stats", methods=["GET"])
def get_provider_stats(provider_id):
    p = Provider.query.get(provider_id)
    if not p:
        return err("Provider not found", 404)

    reviews       = Review.query.filter_by(provider_id=provider_id).all()
    total_reviews = len(reviews)
    avg_rating    = (round(sum(r.rating for r in reviews) / total_reviews, 2)
                     if total_reviews else 0.0)
    five_stars    = sum(1 for r in reviews if r.rating == 5)
    completed     = p.completed_jobs or 0
    score         = p.score or 0
    no_show_count = Report.query.filter_by(provider_id=provider_id).count()

    if score >= 100:
        tier, tier_label, tier_color = "elite",  "Elite Provider", "#F59E0B"
    elif score >= 60:
        tier, tier_label, tier_color = "top",    "Top Performer",  "#2A5298"
    elif score >= 30:
        tier, tier_label, tier_color = "rising", "Rising Star",    "#10B981"
    else:
        tier, tier_label, tier_color = "new",    "New Provider",   "#94A3B8"

    next_milestone = ((completed // 5) + 1) * 5
    jobs_to_next   = next_milestone - completed

    return ok({
        "score":               score,
        "tier":                tier,
        "tier_label":          tier_label,
        "tier_color":          tier_color,
        "completed_jobs":      completed,
        "total_reviews":       total_reviews,
        "avg_rating":          avg_rating,
        "five_star_reviews":   five_stars,
        "no_show_reports":     no_show_count,
        "next_jobs_milestone": next_milestone,
        "jobs_to_next":        jobs_to_next,
        "profile_bonus_given": p.profile_bonus_given or False,  # ✅ added
    })

# ===================== MESSAGING =====================

@app.route("/messages/send", methods=["POST"])
def send_message():
    data          = request.json
    sender_id     = data.get("sender_id")
    sender_type   = data.get("sender_type")
    receiver_id   = data.get("receiver_id")
    receiver_type = data.get("receiver_type")
    content       = data.get("content", "").strip()

    if not all([sender_id, sender_type, receiver_id, receiver_type, content]):
        return err("Please fill all fields")

    msg = Message(
        sender_id=sender_id,     sender_type=sender_type,
        receiver_id=receiver_id, receiver_type=receiver_type,
        content=content)
    db.session.add(msg)
    db.session.commit()

    # ── Smart notification based on message type ──────────────────
    # Detect OFFER_JSON messages and build meaningful notifications
    # instead of sending the raw JSON blob as notification text.
    notif_type = "new_message"
    notif_text = "New message from {name}"

    if content.startswith("OFFER_JSON:"):
        try:
            offer  = _json.loads(content[len("OFFER_JSON:"):])
            status = offer.get("status", "pending")
            desc   = offer.get("description", "Service")
            date   = offer.get("date", "")
            time_s = offer.get("time", "")
            dt_str = f" on {date} at {time_s}" if date else ""

            if status == "pending":
                # Provider → Client: new offer received
                notif_type = "offer_received"
                notif_text = f"\U0001f4cb {{name}} sent you a service offer: \"{desc}\"{dt_str}"
            elif status == "accepted":
                # Client → Provider: offer accepted
                notif_type = "offer_accepted"
                notif_text = f"\u2705 {{name}} accepted your offer: \"{desc}\"{dt_str}"
            elif status == "refused":
                # Client → Provider: offer refused
                notif_type = "offer_refused"
                notif_text = f"\u274c {{name}} declined your offer: \"{desc}\"{dt_str}"
            elif status == "completed":
                # Client → Provider: job marked complete
                notif_type = "job_completed"
                notif_text = f"\u2b50 {{name}} marked \"{desc}\" as completed!"
        except Exception:
            pass  # fall back to generic new_message

    notif_payload = _build_notif_payload(
        sender_type=sender_type, sender_id=sender_id,
        receiver_type=receiver_type, receiver_id=receiver_id,
        text=notif_text, notif_type=notif_type,
    )
    db.session.add(Notification(
        user_id=receiver_id, user_type=receiver_type,
        type=notif_type, message=notif_payload))
    db.session.commit()

    return ok(
        {"id": msg.id, "created_at": msg.created_at.isoformat()},
        "Message sent")


@app.route("/messages/conversation", methods=["GET"])
def get_conversation():
    client_id   = request.args.get("client_id",   type=int)
    provider_id = request.args.get("provider_id", type=int)

    if not client_id or not provider_id:
        return err("client_id and provider_id are required")

    messages = Message.query.filter(
        ((Message.sender_id == client_id)    &
         (Message.sender_type == "client")   &
         (Message.receiver_id == provider_id) &
         (Message.receiver_type == "provider")) |
        ((Message.sender_id == provider_id)  &
         (Message.sender_type == "provider") &
         (Message.receiver_id == client_id)  &
         (Message.receiver_type == "client"))
    ).order_by(Message.created_at.asc()).all()

    return ok([{
        "id":            m.id,
        "sender_id":     m.sender_id,
        "sender_type":   m.sender_type,
        "receiver_id":   m.receiver_id,
        "receiver_type": m.receiver_type,
        "content":       m.content,
        "is_read":       m.is_read,
        "created_at":    m.created_at.isoformat(),
    } for m in messages])


@app.route("/messages/conversations/<int:user_id>", methods=["GET"])
def get_conversations(user_id):
    user_type = request.args.get("user_type", "client")

    if user_type == "client":
        sent     = (db.session.query(Message.receiver_id)
                    .filter_by(sender_id=user_id, sender_type="client"))
        received = (db.session.query(Message.sender_id)
                    .filter_by(receiver_id=user_id, receiver_type="client"))
        partner_ids = set([r[0] for r in sent] + [r[0] for r in received])

        result = []
        for pid in partner_ids:
            provider = Provider.query.get(pid)
            if not provider:
                continue
            last_msg = Message.query.filter(
                ((Message.sender_id == user_id)   &
                 (Message.sender_type == "client") &
                 (Message.receiver_id == pid)      &
                 (Message.receiver_type == "provider")) |
                ((Message.sender_id == pid)        &
                 (Message.sender_type == "provider") &
                 (Message.receiver_id == user_id)  &
                 (Message.receiver_type == "client"))
            ).order_by(Message.created_at.desc()).first()

            unread = Message.query.filter_by(
                sender_id=pid,      sender_type="provider",
                receiver_id=user_id, receiver_type="client",
                is_read=False).count()

            result.append({
                "provider_id":       pid,
                "provider_name":     provider.full_name,
                "provider_photo":    provider.profile_photo,
                "provider_avatar":   provider.avatar_index or 0,
                "category":          provider.category,
                "city":              provider.city,
                "last_message":      last_msg.content if last_msg else "",
                "last_message_time": (last_msg.created_at.isoformat()
                                      if last_msg else ""),
                "unread_count":      unread,
            })
        return ok(result)

    else:
        sent     = (db.session.query(Message.receiver_id)
                    .filter_by(sender_id=user_id, sender_type="provider"))
        received = (db.session.query(Message.sender_id)
                    .filter_by(receiver_id=user_id, receiver_type="provider"))
        client_ids = set([r[0] for r in sent] + [r[0] for r in received])

        result = []
        for cid in client_ids:
            client = Client.query.get(cid)
            if not client:
                continue
            last_msg = Message.query.filter(
                ((Message.sender_id == user_id)     &
                 (Message.sender_type == "provider") &
                 (Message.receiver_id == cid)        &
                 (Message.receiver_type == "client")) |
                ((Message.sender_id == cid)          &
                 (Message.sender_type == "client")   &
                 (Message.receiver_id == user_id)    &
                 (Message.receiver_type == "provider"))
            ).order_by(Message.created_at.desc()).first()

            unread = Message.query.filter_by(
                sender_id=cid,       sender_type="client",
                receiver_id=user_id, receiver_type="provider",
                is_read=False).count()

            result.append({
                "client_id":         cid,
                "client_name":       client.full_name,
                "client_photo":      client.profile_photo,
                "client_avatar":     client.avatar_index or 0,
                "last_message":      last_msg.content if last_msg else "",
                "last_message_time": (last_msg.created_at.isoformat()
                                      if last_msg else ""),
                "unread_count":      unread,
            })
        return ok(result)


@app.route("/messages/read", methods=["PUT"])
def mark_messages_read():
    data        = request.json
    client_id   = data.get("client_id")
    provider_id = data.get("provider_id")
    reader_type = data.get("reader_type")

    if not all([client_id, provider_id, reader_type]):
        return err("client_id, provider_id and reader_type are required")

    if reader_type == "client":
        Message.query.filter_by(
            sender_id=provider_id, sender_type="provider",
            receiver_id=client_id, receiver_type="client",
            is_read=False).update({"is_read": True})
    else:
        Message.query.filter_by(
            sender_id=client_id,  sender_type="client",
            receiver_id=provider_id, receiver_type="provider",
            is_read=False).update({"is_read": True})
    db.session.commit()
    return ok(message="Messages marked as read")

# ===================== FAVORITES =====================

@app.route("/favorites", methods=["POST"])
def add_favorite():
    data        = request.json
    client_id   = data.get("client_id")
    provider_id = data.get("provider_id")

    if not client_id or not provider_id:
        return err("client_id and provider_id are required")
    if Favorite.query.filter_by(
            client_id=client_id, provider_id=provider_id).first():
        return err("Already in favorites", 409)

    db.session.add(Favorite(client_id=client_id, provider_id=provider_id))
    db.session.commit()
    return ok(message="Added to favorites")


@app.route("/favorites", methods=["DELETE"])
def remove_favorite():
    data        = request.json
    client_id   = data.get("client_id")
    provider_id = data.get("provider_id")

    fav = Favorite.query.filter_by(
        client_id=client_id, provider_id=provider_id).first()
    if not fav:
        return err("Favorite not found", 404)

    db.session.delete(fav)
    db.session.commit()
    return ok(message="Removed from favorites")


@app.route("/favorites/<int:client_id>", methods=["GET"])
def get_favorites(client_id):
    favs = Favorite.query.filter_by(client_id=client_id).all()
    result = []
    for f in favs:
        p = Provider.query.get(f.provider_id)
        if p:
            result.append(_provider_summary(p))
    return ok(result)


@app.route("/favorites/check", methods=["GET"])
def check_favorite():
    client_id   = request.args.get("client_id",   type=int)
    provider_id = request.args.get("provider_id", type=int)
    exists = Favorite.query.filter_by(
        client_id=client_id, provider_id=provider_id).first()
    return ok({"is_favorite": exists is not None})

# ===================== REVIEWS =====================

@app.route("/reviews", methods=["POST"])
def add_review():
    data        = request.json
    provider_id = data.get("provider_id")
    client_id   = data.get("client_id")
    rating      = data.get("rating")
    comment     = data.get("comment", "")

    if not all([provider_id, client_id, rating]):
        return err("provider_id, client_id and rating are required")
    if not (1 <= float(rating) <= 5):
        return err("Rating must be between 1 and 5")

    db.session.add(Review(
        provider_id=provider_id, client_id=client_id,
        rating=float(rating), comment=comment))
    db.session.commit()
    update_provider_rating(provider_id)

    p = Provider.query.get(provider_id)
    if p:
        p.completed_jobs = (p.completed_jobs or 0) + 1
        db.session.commit()
    recalc_provider_score(provider_id)

    rating_val    = float(rating)
    notif_payload = _build_notif_payload(
        sender_type="client", sender_id=client_id,
        receiver_type="provider", receiver_id=provider_id,
        text="{name} left you a " + f"{rating_val:.0f}\u2605 review",
        notif_type="new_review",
        extra={"rating": rating_val},
    )
    db.session.add(Notification(
        user_id=provider_id, user_type="provider",
        type="new_review", message=notif_payload))

    if p:
        jobs = p.completed_jobs
        milestone_msg = None
        if jobs == 1:
            milestone_msg = "\U0001f389 Congratulations on completing your first job!"
        elif jobs == 5:
            milestone_msg = "\U0001f3c6 Amazing! You've completed 5 jobs. Keep it up!"
        elif jobs == 10:
            milestone_msg = "\U0001f31f 10 jobs completed! You're a top performer."
        elif jobs % 10 == 0:
            milestone_msg = f"\U0001f680 {jobs} jobs completed! Outstanding work."

        if milestone_msg:
            db.session.add(Notification(
                user_id=provider_id, user_type="provider",
                type="milestone",
                message=_json.dumps({
                    "text":          milestone_msg,
                    "sender_name":   "ALOO",
                    "sender_id":     0,
                    "sender_type":   "system",
                    "receiver_id":   provider_id,
                    "receiver_type": "provider",
                    "sender_photo":  None,
                    "sender_avatar": 0,
                })))

    db.session.commit()
    return ok(message="Review submitted successfully")


@app.route("/reviews/<int:provider_id>", methods=["GET"])
def get_reviews(provider_id):
    reviews = (Review.query
               .filter_by(provider_id=provider_id)
               .order_by(Review.created_at.desc())
               .all())
    result = []
    for r in reviews:
        client = Client.query.get(r.client_id)
        result.append({
            "id":            r.id,
            "client_name":   client.full_name if client else "Unknown",
            "client_photo":  client.profile_photo if client else None,
            "client_avatar": client.avatar_index  if client else 0,
            "rating":        r.rating,
            "comment":       r.comment,
            "created_at":    r.created_at.isoformat(),
        })
    return ok(result)

# ===================== REPORTS =====================

@app.route("/reports", methods=["POST"])
def report_no_show():
    data            = request.json
    client_id       = data.get("client_id")
    provider_id     = data.get("provider_id")
    reservation_key = data.get("reservation_key", "")
    reason          = data.get("reason", "")        # comment shown on review page
    description     = data.get("description", "")
    date            = data.get("date", "")
    time_str        = data.get("time", "")

    if not client_id or not provider_id:
        return err("client_id and provider_id are required")
    if not reservation_key:
        return err("reservation_key is required")

    existing = Report.query.filter_by(
        client_id=client_id,
        provider_id=provider_id,
        reservation_key=reservation_key).first()
    if existing:
        return err("You already reported this reservation", 409)

    # ── 1. Create report record ────────────────────────────
    report = Report(
        client_id=client_id, provider_id=provider_id,
        reservation_key=reservation_key, reason=reason,
        points_deducted=NO_SHOW_PENALTY)
    db.session.add(report)

    # ── 2. Save as a 1-star review on the provider's profile ──
    # The reason field becomes the review comment so clients can
    # see the no-show history on the provider's reviews page.
    no_show_comment = reason.strip() if reason.strip() else "Provider did not show up."
    db.session.add(Review(
        provider_id=provider_id,
        client_id=client_id,
        rating=1.0,
        comment=f"⚠️ No-show report: {no_show_comment}",
    ))
    db.session.commit()

    # Update provider rating average to include this 1-star
    update_provider_rating(provider_id)

    # ── 3. Deduct score points ─────────────────────────────
    p = Provider.query.get(provider_id)
    if p:
        p.score = max(0, (p.score or 0) - NO_SHOW_PENALTY)
        db.session.commit()

    # ── 4. Notify provider ────────────────────────────────
    client      = Client.query.get(client_id)
    client_name = client.full_name if client else "A client"

    notif_payload = _json.dumps({
        "text": (
            f"\u26a0\ufe0f {client_name} reported you as a no-show "
            f"for \"{description}\" on {date} at {time_str}. "
            f"You lost {NO_SHOW_PENALTY} points."
        ),
        "sender_name":   client_name,
        "sender_id":     client_id,
        "sender_type":   "client",
        "receiver_id":   provider_id,
        "receiver_type": "provider",
        "sender_photo":  client.profile_photo if client else None,
        "sender_avatar": client.avatar_index  if client else 0,
        "points_lost":   NO_SHOW_PENALTY,
    })
    db.session.add(Notification(
        user_id=provider_id, user_type="provider",
        type="no_show_report", message=notif_payload))
    db.session.commit()

    return ok({
        "points_deducted": NO_SHOW_PENALTY,
        "new_score":       p.score if p else 0,
    }, f"Report submitted. Provider lost {NO_SHOW_PENALTY} points.")


@app.route("/reports/check", methods=["GET"])
def check_report():
    client_id       = request.args.get("client_id",       type=int)
    provider_id     = request.args.get("provider_id",     type=int)
    reservation_key = request.args.get("reservation_key", "")

    if not client_id or not provider_id or not reservation_key:
        return err("client_id, provider_id and reservation_key are required")

    existing = Report.query.filter_by(
        client_id=client_id,
        provider_id=provider_id,
        reservation_key=reservation_key).first()
    return ok({"already_reported": existing is not None})

# ===================== CLIENT ACCOUNT =====================

@app.route("/client/<int:client_id>", methods=["GET"])
def get_client(client_id):
    c = Client.query.get(client_id)
    if not c:
        return err("Client not found", 404)
    return ok({
        "id":            c.id,
        "full_name":     c.full_name,
        "email":         c.email,
        "phone":         c.phone,
        "address":       c.address,
        "profile_photo": c.profile_photo,
        "avatar_index":  c.avatar_index or 0,
        "created_at":    c.created_at.isoformat(),
    })


@app.route("/client/<int:client_id>", methods=["PUT"])
def update_client(client_id):
    c = Client.query.get(client_id)
    if not c:
        return err("Client not found", 404)

    data = request.json
    for field in ("full_name", "phone", "address",
                  "profile_photo", "avatar_index"):
        if field in data:
            setattr(c, field, data[field])
    db.session.commit()
    return ok(message="Profile updated successfully")


@app.route("/client/<int:client_id>/password", methods=["PUT"])
def change_client_password(client_id):
    c = Client.query.get(client_id)
    if not c:
        return err("Client not found", 404)

    data             = request.json
    current_password = data.get("current_password", "")
    new_password     = data.get("new_password", "")
    new_password2    = data.get("new_password2", "")

    if not bcrypt.check_password_hash(c.password, current_password):
        return err("Current password is incorrect", 401)
    valid, msg = is_valid_password(new_password)
    if not valid:
        return err(msg)
    if new_password != new_password2:
        return err("Passwords do not match")

    c.password = bcrypt.generate_password_hash(new_password).decode("utf-8")
    db.session.commit()
    return ok(message="Password changed successfully")


@app.route("/client/<int:client_id>", methods=["DELETE"])
def delete_client(client_id):
    c = Client.query.get(client_id)
    if not c:
        return err("Client not found", 404)

    data     = request.json
    password = data.get("password", "")
    if not bcrypt.check_password_hash(c.password, password):
        return err("Wrong password", 401)

    db.session.delete(c)
    db.session.commit()
    return ok(message="Account deleted successfully")

# ===================== PROVIDER ACCOUNT =====================

@app.route("/provider/<int:provider_id>", methods=["GET"])
def get_provider_settings(provider_id):
    p = Provider.query.get(provider_id)
    if not p:
        return err("Provider not found", 404)
    return ok({
        **_provider_summary(p),
        "email":      p.email,
        "phone":      p.phone,
        "address":    p.address,
        "is_active":  p.is_active,
        "skills":     p.skills,
        "portfolio":  p.portfolio,
        "created_at": p.created_at.isoformat(),
    })


@app.route("/provider/<int:provider_id>/password", methods=["PUT"])
def change_provider_password(provider_id):
    p = Provider.query.get(provider_id)
    if not p:
        return err("Provider not found", 404)

    data             = request.json
    current_password = data.get("current_password", "")
    new_password     = data.get("new_password", "")
    new_password2    = data.get("new_password2", "")

    if not bcrypt.check_password_hash(p.password, current_password):
        return err("Current password is incorrect", 401)
    valid, msg = is_valid_password(new_password)
    if not valid:
        return err(msg)
    if new_password != new_password2:
        return err("Passwords do not match")

    p.password = bcrypt.generate_password_hash(new_password).decode("utf-8")
    db.session.commit()
    return ok(message="Password changed successfully")


@app.route("/provider/<int:provider_id>", methods=["DELETE"])
def delete_provider(provider_id):
    p = Provider.query.get(provider_id)
    if not p:
        return err("Provider not found", 404)

    data     = request.json
    password = data.get("password", "")
    if not bcrypt.check_password_hash(p.password, password):
        return err("Wrong password", 401)

    db.session.delete(p)
    db.session.commit()
    return ok(message="Account deleted successfully")

# ===================== NOTIFICATIONS =====================

@app.route("/notifications/<int:user_id>", methods=["GET"])
def get_notifications(user_id):
    user_type = request.args.get("user_type", "client")
    notifs    = (Notification.query
                 .filter_by(user_id=user_id, user_type=user_type)
                 .order_by(Notification.created_at.desc())
                 .all())
    return ok([{
        "id":         n.id,
        "type":       n.type,
        "message":    n.message,
        "is_read":    n.is_read,
        "created_at": n.created_at.isoformat(),
    } for n in notifs])


@app.route("/notifications/<int:notif_id>/read", methods=["PUT"])
def mark_notification_read(notif_id):
    n = Notification.query.get(notif_id)
    if not n:
        return err("Notification not found", 404)
    n.is_read = True
    db.session.commit()
    return ok(message="Notification marked as read")


@app.route("/notifications/readall/<int:user_id>", methods=["PUT"])
def mark_all_notifications_read(user_id):
    user_type = request.args.get("user_type", "client")
    (Notification.query
     .filter_by(user_id=user_id, user_type=user_type, is_read=False)
     .update({"is_read": True}))
    db.session.commit()
    return ok(message="All notifications marked as read")


@app.route("/notifications/<int:notif_id>", methods=["DELETE"])
def delete_notification(notif_id):
    n = Notification.query.get(notif_id)
    if not n:
        return err("Notification not found", 404)
    db.session.delete(n)
    db.session.commit()
    return ok(message="Notification deleted")


@app.route("/notifications/deleteall/<int:user_id>", methods=["DELETE"])
def delete_all_notifications(user_id):
    user_type = request.args.get("user_type", "client")
    Notification.query.filter_by(
        user_id=user_id, user_type=user_type).delete()
    db.session.commit()
    return ok(message="All notifications deleted")


@app.route("/notifications/reminder", methods=["POST"])
def create_reminder_notification():
    data         = request.json
    user_id      = data.get('user_id')
    user_type    = data.get('user_type', 'client')
    message      = data.get('message', '')
    reminder_key = data.get('reminder_key', '')
    client_id    = data.get('client_id', 0)
    provider_id  = data.get('provider_id', 0)
    partner_name = data.get('partner_name', '')
    date         = data.get('date', '')
    time_str     = data.get('time', '')
    description  = data.get('description', '')

    if not user_id or not message:
        return err('user_id and message are required')

    payload = _json.dumps({
        "text":          message,
        "sender_name":   "ALOO Reminder",
        "sender_id":     0,
        "sender_type":   "system",
        "receiver_id":   user_id,
        "receiver_type": user_type,
        "sender_photo":  None,
        "sender_avatar": 0,
        "reminder_key":  reminder_key,
        "client_id":     client_id,
        "provider_id":   provider_id,
        "partner_name":  partner_name,
        "date":          date,
        "time":          time_str,
        "description":   description,
    })

    db.session.add(Notification(
        user_id=user_id, user_type=user_type,
        type="reminder", message=payload))
    db.session.commit()
    return ok(message="Reminder created")

# ===================== PORTFOLIO =====================

@app.route('/upload/portfolio-photo', methods=['POST'])
def upload_portfolio_photo():
    if 'file' not in request.files:
        return err('No file provided')

    file        = request.files['file']
    provider_id = request.form.get('provider_id', type=int)

    if not file or file.filename == '':
        return err('No file selected')
    if not allowed_file(file.filename):
        return err('File type not allowed')
    if not provider_id:
        return err('provider_id is required')

    ext      = file.filename.rsplit('.', 1)[1].lower()
    filename = f"portfolio_{provider_id}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)

    photo_url = f"http://192.168.0.184:5000/uploads/profiles/{filename}"
    recalc_provider_score(provider_id)
    return ok({'photo_url': photo_url}, 'Portfolio photo uploaded')


@app.route('/upload/portfolio-photo', methods=['DELETE'])
def delete_portfolio_photo():
    data     = request.json
    filename = data.get('filename', '')
    if filename:
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        try:
            if os.path.exists(filepath):
                os.remove(filepath)
        except Exception:
            pass
    return ok(message='Portfolio photo deleted')

# ===================== CHAT MEDIA =====================

@app.route('/upload/chat-media', methods=['POST'])
def upload_chat_media():
    if 'file' not in request.files:
        return err('No file provided')

    file    = request.files['file']
    user_id = request.form.get('user_id', type=int)
    role    = request.form.get('role', 'client')

    if not file or file.filename == '':
        return err('No file selected')
    if not user_id:
        return err('user_id is required')

    allowed = {'png', 'jpg', 'jpeg', 'webp', 'mp4', 'mov', 'avi', 'mkv'}
    ext = (file.filename.rsplit('.', 1)[1].lower()
           if '.' in file.filename else '')
    if ext not in allowed:
        return err('File type not allowed')

    filename = f"chat_{role}_{user_id}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)

    photo_url = f"http://192.168.0.184:5000/uploads/profiles/{filename}"
    return ok({'photo_url': photo_url}, 'Media uploaded successfully')

# ===================== RUN =====================

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(debug=True, host="0.0.0.0", port=5000)