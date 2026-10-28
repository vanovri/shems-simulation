function verify
% Verify the numerical trajectory and controller boundary cases.
set(groot, 'defaultFigureVisible', 'off');
shems_simulation;
assert(N == 1441, 'Expected 24 hours at one-minute resolution.');
assert(all(isfinite(SOC)) && all(SOC >= SOC_min-1e-9) && all(SOC <= SOC_max+1e-9));
% The terminal sample holds the previous command and is not an integration interval.
balance = P_pv(1:end-1) + P_batt(1:end-1) + P_grid(1:end-1) - P_load(1:end-1);
assert(max(abs(balance)) < 1e-9, 'Power conservation failed.');
y = hems_controller_fcn([5; 1; 95]);
assert(isequal(y, [0; -4; 3]), 'Full battery should export surplus.');
y = hems_controller_fcn([0; 4; 20]);
assert(isequal(y, [0; 4; 5]), 'Minimum SoC should prevent discharge.');
y = hems_controller_fcn([0; 5; 50]);
assert(abs(y(1)-3.5)<1e-9 && abs(y(2)-1.5)<1e-9, 'Discharge limit failed.');
disp('PASS: 1441 samples, SoC bounds, power balance and three controller boundary cases.');
close all force;
end
