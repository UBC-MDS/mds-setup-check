OK_FORMAT = True

test = {
    "name": "q2",
    "points": 1,
    "suites": [{
        "cases": [
            # The slope is negative: more staff, shorter waits. A student who has
            # swapped x and y gets +2.57 and fails here rather than in question 4.
            {"code": ">>> round(float(slope), 3) == -0.389\nTrue", "hidden": False},
            {"code": ">>> round(float(intercept), 3) == 5.854\nTrue", "hidden": False},
            {"code": ">>> round(float(mse), 4) == 0.018\nTrue", "hidden": False},
        ],
        "scored": True,
        "type": "doctest",
    }],
}
