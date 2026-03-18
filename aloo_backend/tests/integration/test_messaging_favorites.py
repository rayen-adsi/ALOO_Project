# -*- coding: utf-8 -*-
"""
tests/integration/test_messaging_favorites.py
Tests for messaging and favorites endpoints.
"""
import pytest


class TestSendMessage:

    def test_send_valid_message(self, client, sample_client, sample_provider):
        res = client.post("/messages/send", json={
            "sender_id":     sample_client.id,
            "sender_type":   "client",
            "receiver_id":   sample_provider.id,
            "receiver_type": "provider",
            "content":       "Hello, are you available tomorrow?",
        })
        data = res.get_json()
        assert res.status_code == 200
        assert data["success"] is True
        assert "id" in data["data"]

    def test_send_creates_notification(self, client, db, sample_client, sample_provider):
        client.post("/messages/send", json={
            "sender_id":     sample_client.id,
            "sender_type":   "client",
            "receiver_id":   sample_provider.id,
            "receiver_type": "provider",
            "content":       "Test notification message",
        })
        from app import Notification
        notif = Notification.query.filter_by(
            user_id=sample_provider.id, type="new_message"
        ).first()
        assert notif is not None

    def test_send_empty_content_rejected(self, client, sample_client, sample_provider):
        res = client.post("/messages/send", json={
            "sender_id":     sample_client.id,
            "sender_type":   "client",
            "receiver_id":   sample_provider.id,
            "receiver_type": "provider",
            "content":       "",
        })
        assert res.status_code == 400

    def test_send_missing_fields(self, client):
        res = client.post("/messages/send", json={"content": "hello"})
        assert res.status_code == 400


class TestGetConversation:

    def test_get_conversation(self, client, sample_client, sample_provider, sample_message):
        res = client.get(
            f"/messages/conversation"
            f"?client_id={sample_client.id}"
            f"&provider_id={sample_provider.id}"
        )
        data = res.get_json()
        assert res.status_code == 200
        assert len(data["data"]) == 1
        assert data["data"][0]["content"] == "Bonjour, etes-vous disponible?"

    def test_missing_params(self, client):
        res = client.get("/messages/conversation?client_id=1")
        assert res.status_code == 400

    def test_empty_conversation(self, client, sample_client, sample_provider):
        res = client.get(
            f"/messages/conversation"
            f"?client_id={sample_client.id}"
            f"&provider_id={sample_provider.id}"
        )
        assert res.get_json()["data"] == []


class TestMarkMessagesRead:

    def test_mark_as_read(self, client, db, sample_client, sample_provider, sample_message):
        res = client.put("/messages/read", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
            "reader_type": "provider",
        })
        assert res.status_code == 200
        from app import Message
        msg = Message.query.get(sample_message.id)
        assert msg.is_read is True

    def test_missing_fields(self, client):
        res = client.put("/messages/read", json={"client_id": 1})
        assert res.status_code == 400


class TestFavorites:

    def test_add_favorite(self, client, sample_client, sample_provider):
        res = client.post("/favorites", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
        })
        assert res.status_code == 200
        assert res.get_json()["success"] is True

    def test_add_duplicate_favorite(self, client, sample_client, sample_provider):
        client.post("/favorites", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
        })
        res = client.post("/favorites", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
        })
        assert res.status_code == 409

    def test_remove_favorite(self, client, sample_client, sample_provider):
        client.post("/favorites", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
        })
        res = client.delete("/favorites", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
        })
        assert res.status_code == 200

    def test_remove_nonexistent_favorite(self, client, sample_client, sample_provider):
        res = client.delete("/favorites", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
        })
        assert res.status_code == 404

    def test_get_favorites_list(self, client, sample_client, sample_provider):
        client.post("/favorites", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
        })
        res = client.get(f"/favorites/{sample_client.id}")
        data = res.get_json()["data"]
        assert len(data) == 1
        assert data[0]["id"] == sample_provider.id

    def test_check_favorite_true(self, client, sample_client, sample_provider):
        client.post("/favorites", json={
            "client_id":   sample_client.id,
            "provider_id": sample_provider.id,
        })
        res = client.get(
            f"/favorites/check"
            f"?client_id={sample_client.id}"
            f"&provider_id={sample_provider.id}"
        )
        assert res.get_json()["data"]["is_favorite"] is True

    def test_check_favorite_false(self, client, sample_client, sample_provider):
        res = client.get(
            f"/favorites/check"
            f"?client_id={sample_client.id}"
            f"&provider_id={sample_provider.id}"
        )
        assert res.get_json()["data"]["is_favorite"] is False

    def test_missing_ids(self, client):
        res = client.post("/favorites", json={"client_id": 1})
        assert res.status_code == 400
