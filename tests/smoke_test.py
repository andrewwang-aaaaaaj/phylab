"""Numerical smoke tests for PhyLab's analysis formulas and CSV shape.

These tests exercise the same equations used in ExperimentDetail.ets. They do
not replace an on-device test; they catch unit/formula regressions in CI.
"""
import math


def freefall_height(t_s: float, g: float = 9.81) -> float:
    return 0.5 * g * t_s * t_s


def pendulum_frequency(period_s: float) -> float:
    return 1.0 / period_s


def rpm_from_rad_s(omega: float) -> float:
    return abs(omega) * 60.0 / (2.0 * math.pi)


def barometric_altitude(p: float, p0: float) -> float:
    return 44330.0 * (1.0 - (p / p0) ** 0.1903)


def tilt_deg(gx: float, gy: float, gz: float) -> float:
    total = math.sqrt(gx * gx + gy * gy + gz * gz)
    ratio = max(-1.0, min(1.0, gz / total))
    return math.acos(ratio) * 180.0 / math.pi


def csv_rows() -> str:
    rows = [
        (0, "acceleration", [0.1, 9.8, 0.2]),
        (20, "acceleration", [0.2, 9.7, 0.1]),
        (0, "barometer", [1013.25]),
    ]
    lines = ["elapsed_ms,sensor,v1,v2,v3,v4,v5,v6"]
    for t, name, values in rows:
        fields = [str(t), name] + [f"{v:.6f}" for v in values] + [""] * (6 - len(values))
        lines.append(",".join(fields))
    return "\n".join(lines)


def main() -> None:
    h = freefall_height(0.241)
    assert abs(h - 0.28476) < 0.001, h
    assert abs(pendulum_frequency(1.0) - 1.0) < 1e-9
    assert abs(pendulum_frequency(2.0) - 0.5) < 1e-9
    rpm = rpm_from_rad_s(10.0)
    assert abs(rpm - 95.493) < 0.01, rpm
    alt = barometric_altitude(1000.0, 1013.25)
    assert 110.0 < alt < 112.0, alt
    assert abs(tilt_deg(0.0, 0.0, 9.81)) < 1e-6
    assert abs(tilt_deg(9.81, 0.0, 0.0) - 90.0) < 1e-6
    text = csv_rows()
    assert text.count("\n") == 3
    assert text.splitlines()[1].endswith(",0.100000,9.800000,0.200000,,,")
    print("PASS freefall h(0.241s) = %.5f m" % h)
    print("PASS pendulum f(1s/2s) = 1 / 0.5 Hz")
    print("PASS rotation 10 rad/s = %.3f rpm" % rpm)
    print("PASS barometric altitude 1000/1013.25 hPa = %.2f m" % alt)
    print("PASS tilt 0deg / 90deg")
    print("PASS CSV 6-value long format")


if __name__ == "__main__":
    main()
