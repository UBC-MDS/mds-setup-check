OK_FORMAT = True

test = {
    "name": "q1",
    "points": 1,
    "suites": [{
        "cases": [
            {"code": ">>> isinstance(mean_wait, float)\nTrue", "hidden": False},
            {"code": ">>> round(float(mean_wait), 2) == 3.71\nTrue", "hidden": False},
        ],
        "scored": True,
        "type": "doctest",
    }],
}
