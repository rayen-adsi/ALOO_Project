# -*- coding: utf-8 -*-
"""
tests/integration/test_auth.py
Tests for login and signup endpoints.
"""
import pytest


class TestLogin:

    def test_client_login_success(self, client, sample_client):
        res = client.post("/auth/login", json={
            "email": "alice@test.com",
            "password": "SecurePass1!"
        })
        data = res.get_json()
        assert res.status_code == 200
        assert data["success"] is True
        assert data["data"]["role"] == "client"
        assert data["data"]["email"] == "alice@test.com"

    def test_provider_login_success(self, client, sample_provider):
        res = client.post("/auth/login", json={
            "email": "bob@test.com",
            "password": "SecurePass1!"
        })
        data = res.get_json()
        assert res.status_code == 200
        assert data["data"]["role"] == "provider"

    def test_wrong_password(self, client, sample_client):
        res = client.post("/auth/login", json={
            "email": "alice@test.com",
            "password": "WrongPass1!"
        })
        assert res.status_code == 401
        assert res.get_json()["success"] is False

    def test_email_not_found(self, client):
        res = client.post("/auth/login", json={
            "email": "nobody@test.com",
            "password": "SecurePass1!"
        })
        assert res.status_code == 401

    def test_missing_fields(self, client):
        res = client.post("/auth/login", json={"email": "alice@test.com"})
        assert res.status_code == 400

    def test_invalid_email_format(self, client):
        res = client.post("/auth/login", json={
            "email": "not-an-email",
            "password": "SecurePass1!"
        })
        assert res.status_code == 400


class TestSignupClient:

    VALID = {
        "full_name": "Charlie Dupont",
        "email": "charlie@test.com",
        "phone": "21111111",
        "password": "SecurePass1!",
        "password2": "SecurePass1!",
        "address": "99 Avenue de la Paix",
    }

    def test_successful_signup(self, client):
        res = client.post("/auth/signup/client", json=self.VALID)
        assert res.status_code == 200
        assert res.get_json()["success"] is True

    def test_duplicate_email(self, client, sample_client):
        payload = {**self.VALID, "email": "alice@test.com"}
        res = client.post("/auth/signup/client", json=payload)
        assert res.status_code == 409

    def test_passwords_do_not_match(self, client):
        payload = {**self.VALID, "password2": "DifferentPass1!"}
        res = client.post("/auth/signup/client", json=payload)
        assert res.status_code == 400
        assert "match" in res.get_json()["message"]

    def test_full_name_too_short(self, client):
        payload = {**self.VALID, "full_name": "Al", "email": "al@test.com"}
        res = client.post("/auth/signup/client", json=payload)
        assert res.status_code == 400

    def test_invalid_email(self, client):
        payload = {**self.VALID, "email": "bad-email"}
        res = client.post("/auth/signup/client", json=payload)
        assert res.status_code == 400

    def test_weak_password(self, client):
        payload = {**self.VALID, "email": "new@test.com",
                   "password": "weak", "password2": "weak"}
        res = client.post("/auth/signup/client", json=payload)
        assert res.status_code == 400

    def test_missing_fields(self, client):
        res = client.post("/auth/signup/client", json={"email": "x@test.com"})
        assert res.status_code == 400

    def test_short_address(self, client):
        payload = {**self.VALID, "email": "new2@test.com", "address": "No"}
        res = client.post("/auth/signup/client", json=payload)
        assert res.status_code == 400


class TestSignupProviderStep1:

    VALID = {
        "full_name": "Diana Electro",
        "email": "diana@test.com",
        "phone": "21222222",
        "password": "SecurePass1!",
        "password2": "SecurePass1!",
    }

    def test_valid_step1(self, client):
        res = client.post("/auth/signup/provider/step1", json=self.VALID)
        assert res.status_code == 200
        assert "validated" in res.get_json()["message"]

    def test_duplicate_provider_email(self, client, sample_provider):
        payload = {**self.VALID, "email": "bob@test.com"}
        res = client.post("/auth/signup/provider/step1", json=payload)
        assert res.status_code == 409

    def test_password_mismatch(self, client):
        payload = {**self.VALID, "password2": "Other1!Pass"}
        res = client.post("/auth/signup/provider/step1", json=payload)
        assert res.status_code == 400


class TestSignupProviderStep2:

    # Using "Plombier" — no accent, safe on all systems
    VALID = {
        "full_name": "Diana Electro",
        "email": "diana@test.com",
        "phone": "21222222",
        "password": "SecurePass1!",
        "category": "Plombier",
        "city": "Sfax",
        "address": "10 Rue Ibn Khaldoun",
        "bio": "Plombier certifie avec 5 ans experience.",
    }

    def test_valid_step2_creates_provider(self, client):
        res = client.post("/auth/signup/provider/step2", json=self.VALID)
        assert res.status_code == 200
        assert res.get_json()["success"] is True

    def test_invalid_category(self, client):
        payload = {**self.VALID, "category": "Astronaute", "email": "x2@test.com"}
        res = client.post("/auth/signup/provider/step2", json=payload)
        assert res.status_code == 400
        assert "category" in res.get_json()["message"].lower()

    def test_bio_too_short(self, client):
        payload = {**self.VALID, "bio": "Short", "email": "x3@test.com"}
        res = client.post("/auth/signup/provider/step2", json=payload)
        assert res.status_code == 400

    def test_missing_fields(self, client):
        res = client.post("/auth/signup/provider/step2", json={})
        assert res.status_code == 400
