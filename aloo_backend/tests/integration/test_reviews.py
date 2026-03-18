# -*- coding: utf-8 -*-
"""
tests/integration/test_reviews.py
Tests for adding and retrieving reviews.
"""
import pytest


class TestAddReview:

    def test_add_valid_review(self, client, sample_client, sample_provider):
        res = client.post("/reviews", json={
            "provider_id": sample_provider.id,
            "client_id":   sample_client.id,
            "rating":      5,
            "comment":     "Excellent service!",
        })
        assert res.status_code == 200
        assert res.get_json()["success"] is True

    def test_rating_updates_provider_avg(self, client, db, sample_client, sample_provider):
        client.post("/reviews", json={
            "provider_id": sample_provider.id,
            "client_id":   sample_client.id,
            "rating":      4,
        })
        from app import Provider
        p = Provider.query.get(sample_provider.id)
        assert p.rating == 4.0
        assert p.total_reviews == 1

    def test_rating_below_1_rejected(self, client, sample_client, sample_provider):
        res = client.post("/reviews", json={
            "provider_id": sample_provider.id,
            "client_id":   sample_client.id,
            "rating":      0,
        })
        assert res.status_code == 400

    def test_rating_above_5_rejected(self, client, sample_client, sample_provider):
        res = client.post("/reviews", json={
            "provider_id": sample_provider.id,
            "client_id":   sample_client.id,
            "rating":      6,
        })
        assert res.status_code == 400

    def test_missing_required_fields(self, client):
        res = client.post("/reviews", json={"rating": 3})
        assert res.status_code == 400

    def test_review_without_comment(self, client, sample_client, sample_provider):
        res = client.post("/reviews", json={
            "provider_id": sample_provider.id,
            "client_id":   sample_client.id,
            "rating":      3,
        })
        assert res.status_code == 200


class TestGetReviews:

    def test_returns_reviews_list(self, client, sample_provider, sample_review):
        res = client.get(f"/reviews/{sample_provider.id}")
        data = res.get_json()
        assert res.status_code == 200
        assert len(data["data"]) == 1
        assert data["data"][0]["rating"] == 4.5

    def test_empty_reviews(self, client, sample_provider):
        res = client.get(f"/reviews/{sample_provider.id}")
        assert res.get_json()["data"] == []

    def test_review_contains_client_name(self, client, sample_provider, sample_review):
        res = client.get(f"/reviews/{sample_provider.id}")
        review = res.get_json()["data"][0]
        assert review["client_name"] == "Alice Martin"
