%% =========================================================================
% PROGRAMMATIC SIMULINK MODEL BUILDER FOR SHEMS
% Membuat file model Simulink (SHEMS_Model.slx) secara otomatis
% Sesuai desain di video Instagram @matlabsolutions
% =========================================================================

clear; clc;
disp('Menyiapkan parameter dan membangun model Simulink...');

% 1. Muat parameter ke Base Workspace
shems_parameters;

% 2. Nama model Simulink
model_name = 'SHEMS_Model';

% Tutup model lama jika sedang terbuka
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

% Buat sistem baru
new_system(model_name);
load_system(model_name);

% Konfigurasi Solvers Simulink & Callbacks Otomatis
set_param(model_name, 'Solver', 'ode45');
set_param(model_name, 'StopTime', '24');
set_param(model_name, 'SolverResetMethod', 'Robust');
set_param(model_name, 'PreLoadFcn', 'shems_parameters;');
set_param(model_name, 'InitFcn', 'shems_parameters;');

%% 3. MENAMBAHKAN BLOK-BLOK SIMULINK

% Blok Clock (Waktu simulasi dalam Jam 0 - 24)
add_block('simulink/Sources/Clock', [model_name '/Clock'], ...
    'Position', [50, 150, 80, 180]);

% Blok 1-D Lookup Table: Profil Daya Solar PV (kW)
add_block('simulink/Lookup Tables/1-D Lookup Table', [model_name '/Solar_PV_Profile'], ...
    'Position', [150, 100, 240, 140], ...
    'Table', 'P_pv', ...
    'BreakpointsForDimension1', 'time');

% Blok 1-D Lookup Table: Profil Beban Rumah (kW)
add_block('simulink/Lookup Tables/1-D Lookup Table', [model_name '/Home_Load_Profile'], ...
    'Position', [150, 200, 240, 240], ...
    'Table', 'P_load', ...
    'BreakpointsForDimension1', 'time');

% Mux Input untuk HEMS Controller: [P_pv, P_load, SOC]
add_block('simulink/Signal Routing/Mux', [model_name '/Mux_Inputs'], ...
    'Position', [290, 120, 295, 230], ...
    'Inputs', '3');

% Blok Interpreted MATLAB Function: HEMS Intelligent Controller
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [model_name '/HEMS_Controller'], ...
    'Position', [340, 145, 460, 205], ...
    'MATLABFcn', 'hems_controller_fcn');

% Demux Output dari HEMS Controller: 1:P_batt, 2:P_grid, 3:mode
add_block('simulink/Signal Routing/Demux', [model_name '/Demux_Outputs'], ...
    'Position', [500, 135, 505, 215], ...
    'Outputs', '3');

% Blok Battery Dynamic Integrator (SOC Model)
% Delta SOC = -P_batt / E_nom * 100 * dt
add_block('simulink/Continuous/Integrator', [model_name '/Battery_SOC_Integrator'], ...
    'Position', [400, 310, 440, 350], ...
    'InitialCondition', 'SOC_init', ...
    'LimitOutput', 'on', ...
    'UpperSaturationLimit', 'SOC_max', ...
    'LowerSaturationLimit', 'SOC_min');

% Gain untuk integrasi SOC: -100 / E_batt_nom
add_block('simulink/Math Operations/Gain', [model_name '/Gain_SOC'], ...
    'Position', [310, 315, 360, 345], ...
    'Gain', '-100 / E_batt_nom');

% Mux untuk Power Balance Scope (P_pv, P_load, P_batt, P_grid)
add_block('simulink/Signal Routing/Mux', [model_name '/Mux_Powers'], ...
    'Position', [640, 100, 645, 230], ...
    'Inputs', '4');

% Scope untuk Visualisasi Sinyal Daya
add_block('simulink/Sinks/Scope', [model_name '/Scope_Power_Balance'], ...
    'Position', [700, 150, 740, 185], ...
    'NumInputPorts', '1');

% Scope untuk Status SOC Baterai
add_block('simulink/Sinks/Scope', [model_name '/Scope_SOC'], ...
    'Position', [550, 315, 590, 345]);

% Display Blocks untuk Monitoring Nilai Numerik Realtime
add_block('simulink/Sinks/Display', [model_name '/Display_P_grid'], ...
    'Position', [600, 250, 680, 280]);

add_block('simulink/Sinks/Display', [model_name '/Display_SOC'], ...
    'Position', [550, 380, 630, 410]);

%% 4. MENGHUBUNGKAN KABEL (SIGNALS / LINES)

% Clock -> Lookup Tables
add_line(model_name, 'Clock/1', 'Solar_PV_Profile/1', 'autorouting', 'on');
add_line(model_name, 'Clock/1', 'Home_Load_Profile/1', 'autorouting', 'on');

% Inputs -> Mux_Inputs -> HEMS Controller
add_line(model_name, 'Solar_PV_Profile/1', 'Mux_Inputs/1', 'autorouting', 'on');
add_line(model_name, 'Home_Load_Profile/1', 'Mux_Inputs/2', 'autorouting', 'on');
add_line(model_name, 'Battery_SOC_Integrator/1', 'Mux_Inputs/3', 'autorouting', 'on');
add_line(model_name, 'Mux_Inputs/1', 'HEMS_Controller/1', 'autorouting', 'on');

% HEMS Controller -> Demux_Outputs
add_line(model_name, 'HEMS_Controller/1', 'Demux_Outputs/1', 'autorouting', 'on');

% Demux Output 1 (P_batt) -> Battery Model
add_line(model_name, 'Demux_Outputs/1', 'Gain_SOC/1', 'autorouting', 'on');
add_line(model_name, 'Gain_SOC/1', 'Battery_SOC_Integrator/1', 'autorouting', 'on');

% Demux Output 2 (P_grid) -> Display
add_line(model_name, 'Demux_Outputs/2', 'Display_P_grid/1', 'autorouting', 'on');

% Battery SOC -> Scopes & Display
add_line(model_name, 'Battery_SOC_Integrator/1', 'Scope_SOC/1', 'autorouting', 'on');
add_line(model_name, 'Battery_SOC_Integrator/1', 'Display_SOC/1', 'autorouting', 'on');

% Mux Powers -> Scope Power Balance
add_line(model_name, 'Solar_PV_Profile/1', 'Mux_Powers/1', 'autorouting', 'on');
add_line(model_name, 'Home_Load_Profile/1', 'Mux_Powers/2', 'autorouting', 'on');
add_line(model_name, 'Demux_Outputs/1', 'Mux_Powers/3', 'autorouting', 'on');
add_line(model_name, 'Demux_Outputs/2', 'Mux_Powers/4', 'autorouting', 'on');
add_line(model_name, 'Mux_Powers/1', 'Scope_Power_Balance/1', 'autorouting', 'on');

%% 5. SIMPAN MODEL SIMULINK
save_system(model_name, fullfile(pwd, [model_name '.slx']));
disp(['Model Simulink berhasil dibuat dan disimpan di: ' fullfile(pwd, [model_name '.slx'])]);
close_system(model_name);
