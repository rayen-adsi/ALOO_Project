"""
tests/unit/test_helpers.py
Unit tests for the pure helper functions in app.py.
These tests do NOT need a database — they run instantly.
"""

import pytest
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from app import is_valid_email, is_valid_password, is_valid_phone


# ══════════════════════════════════════════════
#  is_valid_email
# ══════════════════════════════════════════════

class TestIsValidEmail:

    def test_valid_email(self):
        assert is_valid_email("alice@example.com")

    def test_valid_email_with_subdomain(self):
        assert is_valid_email("user@mail.example.com")

    def test_valid_email_with_dots(self):
        assert is_valid_email("first.last@domain.org")

    def test_missing_at_sign(self):
        assert not is_valid_email("invalidemail.com")

    def test_missing_domain(self):
        assert not is_valid_email("user@")

    def test_empty_string(self):
        assert not is_valid_email("")

    def test_spaces_in_email(self):
        assert not is_valid_email("user @example.com")

    def test_double_at(self):
        assert not is_valid_email("user@@example.com")


# ══════════════════════════════════════════════
#  is_valid_password
# ══════════════════════════════════════════════

class TestIsValidPassword:

    def test_strong_password(self):
        valid, msg = is_valid_password("SecurePass1!")
        assert valid is True
        assert msg == ""

    def test_too_short(self):
        valid, msg = is_valid_password("Ab1!")
        assert valid is False
        assert "8 characters" in msg

    def test_no_uppercase(self):
        valid, msg = is_valid_password("securepass1!")
        assert valid is False
        assert "uppercase" in msg

    def test_no_lowercase(self):
        valid, msg = is_valid_password("SECUREPASS1!")
        assert valid is False
        assert "lowercase" in msg

    def test_no_digit(self):
        valid, msg = is_valid_password("SecurePass!!")
        assert valid is False
        assert "number" in msg

    def test_no_special_character(self):
        valid, msg = is_valid_password("SecurePass12")
        assert valid is False
        assert "special character" in msg

    def test_exactly_8_chars_valid(self):
        valid, msg = is_valid_password("Aa1!aaaa")
        assert valid is True

    def test_empty_password(self):
        valid, msg = is_valid_password("")
        assert valid is False


# ══════════════════════════════════════════════
#  is_valid_phone
# ══════════════════════════════════════════════

class TestIsValidPhone:

    def test_valid_local_number(self):
        assert is_valid_phone("21345678")

    def test_valid_with_plus_prefix(self):
        assert is_valid_phone("+21621345678")

    def test_too_short(self):
        assert not is_valid_phone("1234567")   # only 7 digits

    def test_letters_in_phone(self):
        assert not is_valid_phone("phone123")

    def test_empty_string(self):
        assert not is_valid_phone("")

    def test_valid_15_digits(self):
        assert is_valid_phone("123456789012345")
