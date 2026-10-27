"""Run: python tools/test_vocab_crosscheck.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vocab_crosscheck import norm, check  # noqa: E402


def test_norm():
    assert norm("THANK-YOU") == "thank you"
    assert norm("thank_you") == "thank you"
    assert norm("ACCEPT_1") == "accept"


def test_check():
    found, missing = check(["HELLO", "THANK-YOU", "ZZZ"], ["hello", "thank_you_2", "other"])
    assert found == ["HELLO", "THANK-YOU"] and missing == ["ZZZ"]


if __name__ == "__main__":
    test_norm()
    test_check()
    print("All vocab_crosscheck checks passed.")
