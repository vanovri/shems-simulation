%% =========================================================================
% SHEMS TELEMETRY EXPORTER FOR 3D DIGITAL TWIN
% Menjalankan simulasi SHEMS dan mengekspor telemetri 24 jam ke format JSON
% untuk divisualisasikan pada 3D Digital Twin (God's Eye View).
% =========================================================================

clear; clc;

fprintf('1. Memuat parameter sistem SHEMS...\n');
shems_parameters;

%% 2. SIMULASI ALIRAN DAYA DAN KONTROL BATERAI
P_batt = zeros(1, N);      % Daya Baterai: (+) Discharging, (-) Charging (kW)
P_grid = zeros(1, N);      % Daya Grid:    (+) Impor/Beli,   (-) Ekspor/Jual (kW)
SOC    = zeros(1, N);      % State of Charge (%)
Mode   = zeros(1, N);      % 1: Solar Direct, 2: Solar+Chg, 3: Export Grid, 4: Batt Dischg, 5: Grid Import

SOC(1) = SOC_init;

for k = 1:N-1
    P_pv_now   = P_pv(k);
    P_load_now = P_load(k);
    P_net      = P_pv_now - P_load_now;
    soc_curr   = SOC(k);
    
    if P_net >= 0
        % SURPLUS SURYA
        if soc_curr < SOC_max
            max_possible_charge = (SOC_max - soc_curr) * E_batt_nom / (100 * dt * eta_chg);
            P_chg = min([P_net, P_batt_chg_max, max_possible_charge]);
            P_batt(k) = -P_chg;
            surplus_remaining = P_net - P_chg;
            P_grid(k) = -surplus_remaining;
            if P_grid(k) < -0.01
                Mode(k) = 3; % Ekspor Grid
            else
                Mode(k) = 2; % Solar + Charge
            end
        else
            P_batt(k) = 0;
            P_grid(k) = -P_net;
            Mode(k)   = 3; % Ekspor Grid
        end
    else
        % DEFISIT SURYA
        P_deficit = abs(P_net);
        if soc_curr > SOC_min
            max_possible_discharge = (soc_curr - SOC_min) * E_batt_nom * eta_dis / (100 * dt);
            P_dis = min([P_deficit, P_batt_dis_max, max_possible_discharge]);
            P_batt(k) = P_dis;
            deficit_remaining = P_deficit - P_dis;
            P_grid(k) = deficit_remaining;
            if P_grid(k) > 0.05
                Mode(k) = 5; % Batt + Impor Grid
            else
                Mode(k) = 4; % Beban PV + Baterai
            end
        else
            P_batt(k) = 0;
            P_grid(k) = P_deficit;
            Mode(k)   = 5; % 100% Impor Grid
        end
    end
    
    if P_batt(k) < 0
        delta_SOC = (-P_batt(k) * eta_chg * dt / E_batt_nom) * 100;
    else
        delta_SOC = -(P_batt(k) / eta_dis * dt / E_batt_nom) * 100;
    end
    SOC(k+1) = max(SOC_min, min(SOC_max, SOC(k) + delta_SOC));
end

P_batt(N) = P_batt(N-1);
P_grid(N) = P_grid(N-1);
Mode(N)   = Mode(N-1);

%% 3. REKAPITULASI METRIK ENERGI & BIAYA
E_pv_total     = sum(P_pv) * dt;
E_load_total   = sum(P_load) * dt;
E_grid_import  = sum(max(0, P_grid)) * dt;
E_grid_export  = sum(max(0, -P_grid)) * dt;
E_batt_charge  = sum(max(0, -P_batt)) * dt;
E_batt_dischg  = sum(max(0, P_batt)) * dt;

cost_baseline_per_step = P_load .* tariff_import * dt;
cost_baseline_total    = sum(cost_baseline_per_step);
cost_import_per_step   = max(0, P_grid) .* tariff_import * dt;
revenue_export_per_step = max(0, -P_grid) .* tariff_export * dt;
cost_shems_total       = sum(cost_import_per_step) - sum(revenue_export_per_step);

cost_savings_rp        = cost_baseline_total - cost_shems_total;
cost_savings_pct       = (cost_savings_rp / cost_baseline_total) * 100;
self_consumption_pct   = ((E_pv_total - E_grid_export) / E_pv_total) * 100;
self_sufficiency_pct   = ((E_load_total - E_grid_import) / E_load_total) * 100;

%% 4. SUSUN STRUKTUR DATA JSON UNTUK DIGITAL TWIN
fprintf('2. Menyusun data telemetri JSON...\n');

mode_names = {'Solar Direct', 'Solar+Chg', 'Export Grid', 'Batt Dischg', 'Grid Import'};

% Metadata Sistem & Geografis
data.system.name = 'Jakarta Smart Home Microgrid';
data.system.location.name = 'Monas Smart Energy Station, Jakarta';
data.system.location.latitude = -6.175392;
data.system.location.longitude = 106.827153;
data.system.location.altitude = 35.0;

data.system.specs.pv_rated_kWp = P_pv_rated;
data.system.specs.battery_nominal_kWh = E_batt_nom;
data.system.specs.battery_soc_min = SOC_min;
data.system.specs.battery_soc_max = SOC_max;

% Ringkasan Kinerja Harian
data.summary.total_pv_kWh = round(E_pv_total, 2);
data.summary.total_load_kWh = round(E_load_total, 2);
data.summary.total_grid_import_kWh = round(E_grid_import, 2);
data.summary.total_grid_export_kWh = round(E_grid_export, 2);
data.summary.total_batt_charge_kWh = round(E_batt_charge, 2);
data.summary.total_batt_dischg_kWh = round(E_batt_dischg, 2);
data.summary.self_consumption_pct = round(self_consumption_pct, 1);
data.summary.self_sufficiency_pct = round(self_sufficiency_pct, 1);
data.summary.cost_baseline_rp = round(cost_baseline_total, 2);
data.summary.cost_shems_rp = round(cost_shems_total, 2);
data.summary.cost_savings_rp = round(cost_savings_rp, 2);
data.summary.cost_savings_pct = round(cost_savings_pct, 1);

% Time-Series Telemetry Array
telemetry_list = cell(1, N);
for k = 1:N
    h = floor(time(k));
    m = round((time(k) - h) * 60);
    if m == 60
        h = h + 1;
        m = 0;
    end
    t_str = sprintf('%02d:%02d', h, m);
    
    t_entry.step = k;
    t_entry.time_hour = round(time(k), 4);
    t_entry.timestamp = t_str;
    t_entry.pv_kW = round(P_pv(k), 3);
    t_entry.load_kW = round(P_load(k), 3);
    t_entry.batt_kW = round(P_batt(k), 3);
    t_entry.grid_kW = round(P_grid(k), 3);
    t_entry.soc_pct = round(SOC(k), 2);
    t_entry.mode_id = Mode(k);
    t_entry.mode_label = mode_names{Mode(k)};
    
    telemetry_list{k} = t_entry;
end
data.telemetry = telemetry_list;

%% 5. SIMPAN KE FILE JSON
json_text = jsonencode(data, 'PrettyPrint', true);
output_file = fullfile(pwd, 'shems_telemetry.json');

fid = fopen(output_file, 'w');
if fid == -1
    error('Gagal membuat file %s', output_file);
end
fwrite(fid, json_text, 'char');
fclose(fid);

fprintf('3. Sukses! Telemetri tersimpan di: %s\n', output_file);
fprintf('   Jumlah titik waktu: %d langkah (24 jam)\n', N);
fprintf('   Total Penghematan : Rp %s (%0.1f%%)\n', num2str(cost_savings_rp), cost_savings_pct);
