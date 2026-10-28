# Source and saved-data verification

Verified on 28 October 2026 using Python 3.14 and `python verify_saved.py`.

The saved synthetic telemetry passed checks for 1441 samples at one-minute spacing, finite values, 20–95% SoC limits, the 3.5 kW battery limit, power conservation on all 1440 integration intervals, charge/discharge state updates, and consistency of the rounded energy totals. The final held-command sample is explicitly excluded from the conservation check.

A current MATLAB/Simulink batch run was attempted. It produced no verification output or logfile and ended after about ten minutes with `0xc0000374, Heap corruption`. No running MATLAB process remained when the timeout check ran. The current MATLAB execution, Simulink rebuild and simulation therefore remain unverified. Historical local success logs are not used as evidence for this exported snapshot. `verify.m` is included for a future MATLAB run.

This is a private source snapshot with validated saved synthetic data. It is not a hardware result, tariff claim, or validated production controller. No production system was changed.
