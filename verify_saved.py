"""Validate the saved synthetic telemetry without requiring MATLAB."""
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parent
data = json.loads((root / 'shems_telemetry.json').read_text())
rows = data['telemetry']
assert len(rows) == 1441
for index, row in enumerate(rows):
    assert row['step'] == index + 1
    assert abs(row['time_hour'] - index / 60) < 0.000051
    assert all(math.isfinite(row[key]) for key in ('pv_kW','load_kW','batt_kW','grid_kW','soc_pct'))
    assert 20 <= row['soc_pct'] <= 95
    assert abs(row['batt_kW']) <= 3.5
    if index == len(rows) - 1:
        continue
    residual = row['pv_kW'] + row['batt_kW'] + row['grid_kW'] - row['load_kW']
    assert abs(residual) <= 0.001501, (index, residual)
    power = row['batt_kW']
    delta = (-power * 0.95 if power < 0 else -power / 0.95) / 60 / 10 * 100
    expected = min(95, max(20, row['soc_pct'] + delta))
    assert abs(expected - rows[index + 1]['soc_pct']) <= 0.011, index
for key, column in [('total_pv_kWh','pv_kW'),('total_load_kWh','load_kW')]:
    total = sum(row[column] for row in rows) / 60
    assert abs(total - data['summary'][key]) <= 0.006, key
print('PASS: 1441 saved synthetic samples, time grid, power conservation, SoC limits and state updates')
print('MATLAB execution is a separate check. The terminal held-command sample is excluded from power conservation.')
