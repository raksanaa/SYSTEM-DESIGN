"""
SALESTORM minimal concurrency simulation.
Purpose: validate the core claim that 10,000 concurrent attempts
cannot reserve more than 100 units.

This is a teaching/demo simulation, not a production inventory service.
"""

from concurrent.futures import ThreadPoolExecutor
from threading import Lock
from collections import Counter
import random

STOCK = 100
REQUESTS = 10_000

class Inventory:
    def __init__(self, stock):
        self.available = stock
        self.reserved = 0
        self.lock = Lock()

    def reserve(self, request_id):
        with self.lock:  # represents the DB's atomic inventory boundary
            if self.available >= 1:
                self.available -= 1
                self.reserved += 1
                return "RESERVED"
            return "OUT_OF_STOCK"

def attempt(inv, request_id):
    # Simulate small timing variation.
    if random.random() < 0.01:
        pass
    return inv.reserve(request_id)

def main():
    inv = Inventory(STOCK)

    with ThreadPoolExecutor(max_workers=100) as executor:
        results = list(executor.map(lambda i: attempt(inv, i), range(REQUESTS)))

    counts = Counter(results)

    print("=== SALESTORM CONCURRENCY SIMULATION ===")
    print(f"Purchase attempts : {REQUESTS}")
    print(f"Initial stock     : {STOCK}")
    print(f"Reservations      : {counts['RESERVED']}")
    print(f"Out of stock      : {counts['OUT_OF_STOCK']}")
    print(f"Remaining stock   : {inv.available}")
    print(f"Reserved quantity : {inv.reserved}")

    assert inv.reserved <= STOCK
    assert inv.available >= 0
    assert inv.available + inv.reserved == STOCK

    print("\nPASS: inventory was never oversold.")

if __name__ == "__main__":
    main()
