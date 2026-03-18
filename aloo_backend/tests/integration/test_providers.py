# -*- coding: utf-8 -*-
"""
tests/integration/test_providers.py
Tests for provider listing, search, detail, and update.
"""
import pytest


class TestGetProviders:

    def test_returns_list(self, client, sample_provider):
        res = client.get("/providers")
        data = res.get_json()
        assert res.status_code == 200
        assert data["success"] is True
        assert isinstance(data["data"], list)
        assert len(data["data"]) >= 1

    def test_inactive_provider_not_shown(self, client, db, sample_provider):
        sample_provider.is_active = False
        db.session.commit()
        res = client.get("/providers")
        ids = [p["id"] for p in res.get_json()["data"]]
        assert sample_provider.id not in ids

    def test_provider_fields_present(self, client, sample_provider):
        res = client.get("/providers")
        provider = res.get_json()["data"][0]
        for field in ["id", "full_name", "category", "city", "rating", "bio"]:
            assert field in provider


class TestSearchProviders:

    def test_search_by_name(self, client, sample_provider):
        res = client.get("/providers/search?q=Bob")
        data = res.get_json()["data"]
        assert any(p["full_name"] == "Bob Plombier" for p in data)

    def test_search_by_category(self, client, sample_provider):
        res = client.get("/providers/search?category=Plombier")
        data = res.get_json()["data"]
        assert all(p["category"] == "Plombier" for p in data)

    def test_search_by_city(self, client, sample_provider):
        res = client.get("/providers/search?city=Tunis")
        data = res.get_json()["data"]
        assert all(p["city"] == "Tunis" for p in data)

    def test_search_no_results(self, client, sample_provider):
        res = client.get("/providers/search?q=Nobody123")
        assert res.get_json()["data"] == []

    def test_search_combined_filters(self, client, sample_provider):
        res = client.get("/providers/search?category=Plombier&city=Tunis")
        data = res.get_json()["data"]
        assert len(data) >= 1


class TestGetProviderById:

    def test_existing_provider(self, client, sample_provider):
        res = client.get(f"/providers/{sample_provider.id}")
        data = res.get_json()
        assert res.status_code == 200
        assert data["data"]["email"] == "bob@test.com"

    def test_provider_includes_reviews(self, client, sample_provider, sample_review):
        res = client.get(f"/providers/{sample_provider.id}")
        reviews = res.get_json()["data"]["reviews"]
        assert len(reviews) == 1
        assert reviews[0]["rating"] == 4.5

    def test_nonexistent_provider(self, client):
        res = client.get("/providers/99999")
        assert res.status_code == 404


class TestUpdateProvider:

    def test_update_bio(self, client, sample_provider):
        res = client.put(f"/providers/{sample_provider.id}", json={
            "bio": "Nouvelle bio mise a jour avec plus de details."
        })
        assert res.status_code == 200
        assert res.get_json()["success"] is True

    def test_update_city(self, client, sample_provider):
        res = client.put(f"/providers/{sample_provider.id}", json={"city": "Sousse"})
        assert res.status_code == 200

    def test_update_nonexistent_provider(self, client):
        res = client.put("/providers/99999", json={"bio": "test"})
        assert res.status_code == 404

    def test_toggle_inactive(self, client, sample_provider):
        res = client.put(f"/providers/{sample_provider.id}", json={"is_active": False})
        assert res.status_code == 200
