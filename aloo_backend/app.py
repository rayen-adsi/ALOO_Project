import re
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_bcrypt import Bcrypt
from datetime import datetime
from sqlalchemy import UniqueConstraint

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
    id            = db.Column(db.Integer, primary_key=True)
    full_name     = db.Column(db.String(100), nullable=False)
    email         = db.Column(db.String(120), unique=True, nullable=False)
    phone         = db.Column(db.String(20), nullable=False)
    password      = db.Column(db.String(255), nullable=False)
    address       = db.Column(db.String(255), nullable=False)
    profile_photo = db.Column(db.Text, nullable=True)
    created_at    = db.Column(db.DateTime, default=datetime.utcnow)


class Provider(db.Model):
    __tablename__  = "providers"
    id             = db.Column(db.Integer, primary_key=True)
    full_name      = db.Column(db.String(100), nullable=False)
    email          = db.Column(db.String(120), unique=True, nullable=False)
    phone          = db.Column(db.String(20), nullable=False)
    password       = db.Column(db.String(255), nullable=False)
    category       = db.Column(db.String(100), nullable=False)
    city           = db.Column(db.String(100), nullable=False)
    address        = db.Column(db.String(255), nullable=False)
    bio            = db.Column(db.Text, nullable=False)
    profile_photo  = db.Column(db.Text, nullable=True)
    rating         = db.Column(db.Float, default=0.0)
    total_reviews  = db.Column(db.Integer, default=0)
    is_verified    = db.Column(db.Boolean, default=False)
    is_active      = db.Column(db.Boolean, default=True)
    created_at     = db.Column(db.DateTime, default=datetime.utcnow)


class Message(db.Model):
    __tablename__  = "messages"
    id             = db.Column(db.Integer, primary_key=True)
    sender_id      = db.Column(db.Integer, nullable=False)
    sender_type    = db.Column(db.String(10), nullable=False)   # 'client' | 'provider'
    receiver_id    = db.Column(db.Integer, nullable=False)
    receiver_type  = db.Column(db.String(10), nullable=False)   # 'client' | 'provider'
    content        = db.Column(db.Text, nullable=False)
    is_read        = db.Column(db.Boolean, default=False)
    created_at     = db.Column(db.DateTime, default=datetime.utcnow)


class Favorite(db.Model):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("client_id", "provider_id"),)
    id          = db.Column(db.Integer, primary_key=True)
    client_id   = db.Column(db.Integer, nullable=False)
    provider_id = db.Column(db.Integer, nullable=False)
    created_at  = db.Column(db.DateTime, default=datetime.utcnow)


class Review(db.Model):
    __tablename__ = "reviews"
    id          = db.Column(db.Integer, primary_key=True)
    provider_id = db.Column(db.Integer, nullable=False)
    client_id   = db.Column(db.Integer, nullable=False)
    rating      = db.Column(db.Float, nullable=False)
    comment     = db.Column(db.Text, nullable=True)
    created_at  = db.Column(db.DateTime, default=datetime.utcnow)


class Notification(db.Model):
    __tablename__ = "notifications"
    id          = db.Column(db.Integer, primary_key=True)
    user_id     = db.Column(db.Integer, nullable=False)
    user_type   = db.Column(db.String(10), nullable=False)   # 'client' | 'provider'
    type        = db.Column(db.String(30), nullable=False)   # 'new_message' | 'new_review'
    message     = db.Column(db.Text, nullable=False)
    is_read     = db.Column(db.Boolean, default=False)
    created_at  = db.Column(db.DateTime, default=datetime.utcnow)


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
    avg     = round(sum(r.rating for r in reviews) / count, 2) if count > 0 else 0.0
    provider = Provider.query.get(provider_id)
    if provider:
        provider.rating       = avg
        provider.total_reviews = count
        db.session.commit()

VALID_CATEGORIES = [
    "Plombier", "Électricien", "Mécanicien",
    "Femme de ménage", "Professeur", "Développeur", "Réparation domicile"
]

# ===================== PING =====================

@app.route("/ping")
def ping():
    return ok(message="Backend connected")

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
        "role":      role,
        "id":        user.id,
        "full_name": user.full_name,
        "email":     user.email,
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

    hashed_pw = bcrypt.generate_password_hash(password).decode("utf-8")
    db.session.add(Client(full_name=full_name, email=email, phone=phone,
                          password=hashed_pw, address=address))
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

    hashed_pw = bcrypt.generate_password_hash(password).decode("utf-8")
    db.session.add(Provider(full_name=full_name, email=email, phone=phone,
                            password=hashed_pw, category=category, city=city,
                            address=address, bio=bio))
    db.session.commit()
    return ok(message="Provider account created successfully")

# ===================== PROVIDERS =====================

@app.route("/providers", methods=["GET"])
def get_providers():
    providers = Provider.query.filter_by(is_active=True).all()
    return ok([{
        "id": p.id, "full_name": p.full_name, "category": p.category,
        "city": p.city, "bio": p.bio, "rating": p.rating,
        "total_reviews": p.total_reviews, "is_verified": p.is_verified,
        "profile_photo": p.profile_photo,
    } for p in providers])


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

    providers = query.all()
    return ok([{
        "id": p.id, "full_name": p.full_name, "category": p.category,
        "city": p.city, "bio": p.bio, "rating": p.rating,
        "total_reviews": p.total_reviews, "is_verified": p.is_verified,
        "profile_photo": p.profile_photo,
    } for p in providers])


@app.route("/providers/<int:provider_id>", methods=["GET"])
def get_provider(provider_id):
    p = Provider.query.get(provider_id)
    if not p:
        return err("Provider not found", 404)

    reviews = Review.query.filter_by(provider_id=provider_id).order_by(Review.created_at.desc()).all()
    reviews_data = []
    for r in reviews:
        client = Client.query.get(r.client_id)
        reviews_data.append({
            "client_name": client.full_name if client else "Unknown",
            "rating":      r.rating,
            "comment":     r.comment,
            "created_at":  r.created_at.isoformat(),
        })

    return ok({
        "id": p.id, "full_name": p.full_name, "email": p.email,
        "phone": p.phone, "category": p.category, "city": p.city,
        "address": p.address, "bio": p.bio, "rating": p.rating,
        "total_reviews": p.total_reviews, "is_verified": p.is_verified,
        "is_active": p.is_active, "profile_photo": p.profile_photo,
        "reviews": reviews_data,
    })


@app.route("/providers/<int:provider_id>", methods=["PUT"])
def update_provider(provider_id):
    p = Provider.query.get(provider_id)
    if not p:
        return err("Provider not found", 404)

    data = request.json
    if "bio"           in data: p.bio           = data["bio"]
    if "city"          in data: p.city          = data["city"]
    if "address"       in data: p.address       = data["address"]
    if "profile_photo" in data: p.profile_photo = data["profile_photo"]
    if "is_active"     in data: p.is_active     = data["is_active"]
    db.session.commit()
    return ok(message="Profile updated successfully")

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
    if sender_type not in ["client", "provider"]:
        return err("Invalid sender_type")
    if receiver_type not in ["client", "provider"]:
        return err("Invalid receiver_type")

    msg = Message(sender_id=sender_id, sender_type=sender_type,
                  receiver_id=receiver_id, receiver_type=receiver_type,
                  content=content)
    db.session.add(msg)
    db.session.commit()

    # Create notification for receiver
    notif_msg = f"New message from {sender_type} #{sender_id}"
    db.session.add(Notification(user_id=receiver_id, user_type=receiver_type,
                                type="new_message", message=notif_msg))
    db.session.commit()

    return ok({"id": msg.id, "created_at": msg.created_at.isoformat()},
              "Message sent")


@app.route("/messages/conversation", methods=["GET"])
def get_conversation():
    client_id   = request.args.get("client_id", type=int)
    provider_id = request.args.get("provider_id", type=int)

    if not client_id or not provider_id:
        return err("client_id and provider_id are required")

    messages = Message.query.filter(
        ((Message.sender_id == client_id)   & (Message.sender_type == "client")   &
         (Message.receiver_id == provider_id) & (Message.receiver_type == "provider")) |
        ((Message.sender_id == provider_id) & (Message.sender_type == "provider") &
         (Message.receiver_id == client_id)  & (Message.receiver_type == "client"))
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
        sent     = db.session.query(Message.receiver_id).filter_by(sender_id=user_id, sender_type="client")
        received = db.session.query(Message.sender_id).filter_by(receiver_id=user_id, receiver_type="client")
        provider_ids = set([r[0] for r in sent] + [r[0] for r in received])

        result = []
        for pid in provider_ids:
            provider = Provider.query.get(pid)
            if not provider:
                continue
            last_msg = Message.query.filter(
                ((Message.sender_id == user_id)   & (Message.sender_type == "client")   &
                 (Message.receiver_id == pid)      & (Message.receiver_type == "provider")) |
                ((Message.sender_id == pid)        & (Message.sender_type == "provider") &
                 (Message.receiver_id == user_id)  & (Message.receiver_type == "client"))
            ).order_by(Message.created_at.desc()).first()

            unread = Message.query.filter_by(
                sender_id=pid, sender_type="provider",
                receiver_id=user_id, receiver_type="client", is_read=False
            ).count()

            result.append({
                "provider_id":       pid,
                "provider_name":     provider.full_name,
                "category":          provider.category,
                "city":              provider.city,
                "last_message":      last_msg.content if last_msg else "",
                "last_message_time": last_msg.created_at.isoformat() if last_msg else "",
                "unread_count":      unread,
            })
        return ok(result)

    else:  # provider
        sent     = db.session.query(Message.receiver_id).filter_by(sender_id=user_id, sender_type="provider")
        received = db.session.query(Message.sender_id).filter_by(receiver_id=user_id, receiver_type="provider")
        client_ids = set([r[0] for r in sent] + [r[0] for r in received])

        result = []
        for cid in client_ids:
            client = Client.query.get(cid)
            if not client:
                continue
            last_msg = Message.query.filter(
                ((Message.sender_id == user_id) & (Message.sender_type == "provider") &
                 (Message.receiver_id == cid)   & (Message.receiver_type == "client")) |
                ((Message.sender_id == cid)     & (Message.sender_type == "client")   &
                 (Message.receiver_id == user_id) & (Message.receiver_type == "provider"))
            ).order_by(Message.created_at.desc()).first()

            unread = Message.query.filter_by(
                sender_id=cid, sender_type="client",
                receiver_id=user_id, receiver_type="provider", is_read=False
            ).count()

            result.append({
                "client_id":         cid,
                "client_name":       client.full_name,
                "last_message":      last_msg.content if last_msg else "",
                "last_message_time": last_msg.created_at.isoformat() if last_msg else "",
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
        Message.query.filter_by(sender_id=provider_id, sender_type="provider",
                                receiver_id=client_id, receiver_type="client",
                                is_read=False).update({"is_read": True})
    else:
        Message.query.filter_by(sender_id=client_id, sender_type="client",
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
    if Favorite.query.filter_by(client_id=client_id, provider_id=provider_id).first():
        return err("Already in favorites", 409)

    db.session.add(Favorite(client_id=client_id, provider_id=provider_id))
    db.session.commit()
    return ok(message="Added to favorites")


@app.route("/favorites", methods=["DELETE"])
def remove_favorite():
    data        = request.json
    client_id   = data.get("client_id")
    provider_id = data.get("provider_id")

    fav = Favorite.query.filter_by(client_id=client_id, provider_id=provider_id).first()
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
            result.append({
                "id": p.id, "full_name": p.full_name, "category": p.category,
                "city": p.city, "rating": p.rating, "profile_photo": p.profile_photo,
            })
    return ok(result)


@app.route("/favorites/check", methods=["GET"])
def check_favorite():
    client_id   = request.args.get("client_id", type=int)
    provider_id = request.args.get("provider_id", type=int)

    exists = Favorite.query.filter_by(client_id=client_id, provider_id=provider_id).first()
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

    db.session.add(Review(provider_id=provider_id, client_id=client_id,
                          rating=float(rating), comment=comment))
    db.session.commit()

    # Update provider rating
    update_provider_rating(provider_id)

    # Notify provider
    db.session.add(Notification(user_id=provider_id, user_type="provider",
                                type="new_review",
                                message=f"You received a new {rating}★ review"))
    db.session.commit()

    return ok(message="Review submitted successfully")


@app.route("/reviews/<int:provider_id>", methods=["GET"])
def get_reviews(provider_id):
    reviews = Review.query.filter_by(provider_id=provider_id)\
                          .order_by(Review.created_at.desc()).all()
    result = []
    for r in reviews:
        client = Client.query.get(r.client_id)
        result.append({
            "id":          r.id,
            "client_name": client.full_name if client else "Unknown",
            "rating":      r.rating,
            "comment":     r.comment,
            "created_at":  r.created_at.isoformat(),
        })
    return ok(result)

# ===================== CLIENT ACCOUNT =====================

@app.route("/client/<int:client_id>", methods=["GET"])
def get_client(client_id):
    c = Client.query.get(client_id)
    if not c:
        return err("Client not found", 404)
    return ok({
        "id": c.id, "full_name": c.full_name, "email": c.email,
        "phone": c.phone, "address": c.address, "profile_photo": c.profile_photo,
        "created_at": c.created_at.isoformat(),
    })


@app.route("/client/<int:client_id>", methods=["PUT"])
def update_client(client_id):
    c = Client.query.get(client_id)
    if not c:
        return err("Client not found", 404)

    data = request.json
    if "full_name"     in data: c.full_name     = data["full_name"]
    if "phone"         in data: c.phone         = data["phone"]
    if "address"       in data: c.address       = data["address"]
    if "profile_photo" in data: c.profile_photo = data["profile_photo"]
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
        "id": p.id, "full_name": p.full_name, "email": p.email,
        "phone": p.phone, "category": p.category, "city": p.city,
        "address": p.address, "bio": p.bio, "profile_photo": p.profile_photo,
        "rating": p.rating, "total_reviews": p.total_reviews,
        "is_verified": p.is_verified, "is_active": p.is_active,
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
    notifs    = Notification.query.filter_by(user_id=user_id, user_type=user_type)\
                                  .order_by(Notification.created_at.desc()).all()
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
    Notification.query.filter_by(user_id=user_id, user_type=user_type, is_read=False)\
                      .update({"is_read": True})
    db.session.commit()
    return ok(message="All notifications marked as read")


# ===================== RUN =====================

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(debug=True, host="0.0.0.0", port=5000)