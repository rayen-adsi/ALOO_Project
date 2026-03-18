# -*- coding: utf-8 -*-
"""
tests/integration/test_accounts.py
Tests for client and provider account management.
"""
import pytest


class TestClientAccount:

    def test_get_client(self, client, sample_client):
        res = client.get(f"/client/{sample_client.id}")
        data = res.get_json()
        assert res.status_code == 200
        assert data["data"]["email"] == "alice@test.com"
        assert data["data"]["full_name"] == "Alice Martin"

    def test_get_nonexistent_client(self, client):
        res = client.get("/client/99999")
        assert res.status_code == 404

    def test_update_client_name(self, client, sample_client):
        res = client.put(f"/client/{sample_client.id}", json={
            "full_name": "Alice Updated"
        })
        assert res.status_code == 200
        get_res = client.get(f"/client/{sample_client.id}")
        assert get_res.get_json()["data"]["full_name"] == "Alice Updated"

    def test_update_client_phone(self, client, sample_client):
        res = client.put(f"/client/{sample_client.id}", json={"phone": "29999999"})
        assert res.status_code == 200

    def test_update_nonexistent_client(self, client):
        res = client.put("/client/99999", json={"full_name": "Ghost"})
        assert res.status_code == 404

    def test_change_password_success(self, client, sample_client):
        res = client.put(f"/client/{sample_client.id}/password", json={
            "current_password": "SecurePass1!",
            "new_password":     "NewSecure2@",
            "new_password2":    "NewSecure2@",
        })
        assert res.status_code == 200
        assert res.get_json()["success"] is True

    def test_change_password_wrong_current(self, client, sample_client):
        res = client.put(f"/client/{sample_client.id}/password", json={
            "current_password": "WrongPass1!",
            "new_password":     "NewSecure2@",
            "new_password2":    "NewSecure2@",
        })
        assert res.status_code == 401

    def test_change_password_mismatch(self, client, sample_client):
        res = client.put(f"/client/{sample_client.id}/password", json={
            "current_password": "SecurePass1!",
            "new_password":     "NewSecure2@",
            "new_password2":    "DifferentPass1!",
        })
        assert res.status_code == 400

    def test_change_password_weak_new(self, client, sample_client):
        res = client.put(f"/client/{sample_client.id}/password", json={
            "current_password": "SecurePass1!",
            "new_password":     "weak",
            "new_password2":    "weak",
        })
        assert res.status_code == 400

    def test_delete_client_success(self, client, sample_client):
        res = client.delete(f"/client/{sample_client.id}", json={
            "password": "SecurePass1!"
        })
        assert res.status_code == 200
        get_res = client.get(f"/client/{sample_client.id}")
        assert get_res.status_code == 404

    def test_delete_client_wrong_password(self, client, sample_client):
        res = client.delete(f"/client/{sample_client.id}", json={
            "password": "WrongPass1!"
        })
        assert res.status_code == 401

    def test_delete_nonexistent_client(self, client):
        res = client.delete("/client/99999", json={"password": "SecurePass1!"})
        assert res.status_code == 404


class TestProviderAccount:

    def test_get_provider_settings(self, client, sample_provider):
        res = client.get(f"/provider/{sample_provider.id}")
        data = res.get_json()
        assert res.status_code == 200
        assert data["data"]["category"] == "Plombier"
        assert data["data"]["city"] == "Tunis"

    def test_get_nonexistent_provider(self, client):
        res = client.get("/provider/99999")
        assert res.status_code == 404

    def test_change_provider_password_success(self, client, sample_provider):
        res = client.put(f"/provider/{sample_provider.id}/password", json={
            "current_password": "SecurePass1!",
            "new_password":     "NewSecure2@",
            "new_password2":    "NewSecure2@",
        })
        assert res.status_code == 200

    def test_change_provider_password_wrong_current(self, client, sample_provider):
        res = client.put(f"/provider/{sample_provider.id}/password", json={
            "current_password": "WrongPass!!",
            "new_password":     "NewSecure2@",
            "new_password2":    "NewSecure2@",
        })
        assert res.status_code == 401

    def test_delete_provider_success(self, client, sample_provider):
        res = client.delete(f"/provider/{sample_provider.id}", json={
            "password": "SecurePass1!"
        })
        assert res.status_code == 200

    def test_delete_provider_wrong_password(self, client, sample_provider):
        res = client.delete(f"/provider/{sample_provider.id}", json={
            "password": "WrongPass!!"
        })
        assert res.status_code == 401
