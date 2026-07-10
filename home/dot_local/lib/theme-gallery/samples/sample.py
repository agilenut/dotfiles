"""Palette sample: Python — docstrings, strings, numbers, keywords, types."""
from __future__ import annotations

MAX_RETRIES: int = 3


class Greeter:
    """Builds greetings."""

    def __init__(self, name: str = "world") -> None:
        self.name = name

    def greet(self) -> str:
        parts = [f"hello {self.name} ({i})\n" for i in range(MAX_RETRIES)]
        return "".join(parts)


if __name__ == "__main__":
    print(Greeter("palette").greet())
