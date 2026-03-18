# -*- coding: utf-8 -*-
"""
conftest.py - Shared fixtures for all Aloo tests.
Place this file inside aloo_backend/ next to app.py
"""

import os
import sys
import pytest

# Force UTF-8 for Windows Python 3.14
os.environ["PYTHONUTF8"] = "1"
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# Make sure app.py is importable
sys.path.insert(0, os.path.dirname(__file__))

# Force test DB before app initializes SQLAlchemy.
os.environ["DATABASE_URL"] = "sqlite:///:memory:"

from app import app as flask_app, db as _db, bcrypt


# ──────────────────────────────────────────────
#  App + DB setup
# ──────────────────────────────────────────────

@pytest.fixture(scope="session")
def app():
    """Flask app using SQLite in-memory — no PostgreSQL needed."""
    flask_app.config.update({
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
        "SQLALCHEMY_TRACK_MODIFICATIONS": False,
    })
    with flask_app.app_context():
        _db.create_all()
        yield flask_app
        _db.drop_all()


@pytest.fixture(scope="function")
def db(app):
    """Clean database for every single test."""
    with app.app_context():
        yield _db
        _db.session.rollback()
        for table in reversed(_db.metadata.sorted_tables):
            _db.session.execute(table.delete())
        _db.session.commit()


@pytest.fixture(scope="function")
def client(app):
    """Flask test client."""
    return flask_app.test_client()


# ──────────────────────────────────────────────
#  Sample data fixtures  (pure ASCII only)
# ──────────────────────────────────────────────

@pytest.fixture
def sample_client(db):
    from app import Client
    hashed = bcrypt.generate_password_hash("SecurePass1!").decode("utf-8")
    c = Client(
        full_name="Alice Martin",
        email="alice@test.com",
        phone="21345678",
        password=hashed,
        address="12 Rue de la Paix",
    )
    db.session.add(c)
    db.session.commit()
    return c


@pytest.fixture
def sample_provider(db):
    from app import Provider
    hashed = bcrypt.generate_password_hash("SecurePass1!").decode("utf-8")
    p = Provider(
        full_name="Bob Plombier",
        email="bob@test.com",
        phone="21987654",
        password=hashed,
        category="Plombier",
        city="Tunis",
        address="45 Avenue Habib",
        bio="Expert plombier avec 10 ans experience.",
    )
    db.session.add(p)
    db.session.commit()
    return p


@pytest.fixture
def sample_review(db, sample_client, sample_provider):
    from app import Review
    r = Review(
        provider_id=sample_provider.id,
        client_id=sample_client.id,
        rating=4.5,
        comment="Tres bon travail!",
    )
    db.session.add(r)
    db.session.commit()
    return r


@pytest.fixture
def sample_message(db, sample_client, sample_provider):
    from app import Message
    m = Message(
        sender_id=sample_client.id,
        sender_type="client",
        receiver_id=sample_provider.id,
        receiver_type="provider",
        content="Bonjour, etes-vous disponible?",
    )
    db.session.add(m)
    db.session.commit()
    return m
