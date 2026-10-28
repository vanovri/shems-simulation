%% =========================================================================
% SMART HOME ENERGY MANAGEMENT SYSTEM (SHEMS) - 24-HOUR SIMULATION
% Memodelkan aliran daya, interaksi BESS, pertukaran Grid, dan Analisis Biaya
% =========================================================================

clear; close all; clc;

% 1. Muat parameter sistem
shems_parameters;

%% 2. INISIALISASI VARIABEL ARRAY
P_batt = zeros(1, N);      % Daya Baterai: (+) Discharging, (-) Charging (kW)
P_grid = zeros(1, N);      % Daya Grid:    (+) Impor/Beli,   (-) Ekspor/Jual (kW)
SOC    = zeros(1, N);      % State of Charge (%)
Mode   = zeros(1, N);      % 1: Solar Direct, 2: Solar+Chg, 3: Export Grid, 4: Batt Dischg, 5: Grid Import

SOC(1) = SOC_init;

%% 3. SIMULASI DINAMIKA SISTEM DENGAN ALGORITMA HEMS CONTROLLER
for k = 1:N-1
    P_pv_now   = P_pv(k);
    P_load_now = P_load(k);
    P_net      = P_pv_now - P_load_now; % Selisih daya surya vs beban
    soc_curr   = SOC(k);
    
    if P_net >= 0
        % -------------------------------------------------------------
        % KONDISI 1: SURPLUS ENERGI SURYA (P_pv >= P_load)
        % -------------------------------------------------------------
        if soc_curr < SOC_max
            % Prioritas 1: Isi baterai dengan sisa daya surya
            max_possible_charge = (SOC_max - soc_curr) * E_batt_nom / (100 * dt * eta_chg);
            P_chg = min([P_net, P_batt_chg_max, max_possible_charge]);
            
            P_batt(k) = -P_chg; % Daya negatif = charging
            surplus_remaining = P_net - P_chg;
            
            % Jika masih ada sisa setelah mengisi baterai -> Ekspor ke Grid
            P_grid(k) = -surplus_remaining; 
            
            if P_grid(k) < -0.01
                Mode(k) = 3; % Mode Ekspor ke Grid
            else
                Mode(k) = 2; % Mode Solar Suplai Beban + Charge Baterai
            end
        else
            % Baterai sudah penuh (SOC >= SOC_max) -> Seluruh surplus diekspor
            P_batt(k) = 0;
            P_grid(k) = -P_net;
            Mode(k)   = 3; % Ekspor ke Grid
        end
        
    else
        % -------------------------------------------------------------
        % KONDISI 2: DEFISIT ENERGI SURYA (P_pv < P_load)
        % -------------------------------------------------------------
        P_deficit = abs(P_net);
        
        if soc_curr > SOC_min
            % Prioritas 1: Gunakan energi baterai (Discharging)
            max_possible_discharge = (soc_curr - SOC_min) * E_batt_nom * eta_dis / (100 * dt);
            P_dis = min([P_deficit, P_batt_dis_max, max_possible_discharge]);
            
            P_batt(k) = P_dis; % Daya positif = discharging
            deficit_remaining = P_deficit - P_dis;
            
            % Sisa defisit yang tidak tertutupi baterai diambil dari Grid PLN
            P_grid(k) = deficit_remaining;
            
            if P_grid(k) > 0.05
                Mode(k) = 5; % Kombinasi Baterai + Impor Grid
            else
                Mode(k) = 4; % Beban ditutupi PV + Baterai
            end
        else
            % Baterai sudah mencapai batas minimum (SOC <= SOC_min)
            P_batt(k) = 0;
            P_grid(k) = P_deficit; % 100% defisit diimpor dari Grid
            Mode(k)   = 5; % Impor dari Grid
        end
    end
    
    % Pembaruan Dinamika State of Charge (SOC) Baterai
    if P_batt(k) < 0
        % Pengisian (Charging)
        delta_SOC = (-P_batt(k) * eta_chg * dt / E_batt_nom) * 100;
    else
        % Pengosongan (Discharging)
        delta_SOC = -(P_batt(k) / eta_dis * dt / E_batt_nom) * 100;
    end
    
    SOC(k+1) = max(SOC_min, min(SOC_max, SOC(k) + delta_SOC));
end

% Set nilai langkah terakhir
P_batt(N) = P_batt(N-1);
P_grid(N) = P_grid(N-1);
Mode(N)   = Mode(N-1);

%% 4. ANALISIS ENERGI DAN PENGHEMATAN BIAYA
% Menghitung Total Energi (kWh)
E_pv_total     = sum(P_pv) * dt;
E_load_total   = sum(P_load) * dt;
E_grid_import  = sum(max(0, P_grid)) * dt;
E_grid_export  = sum(max(0, -P_grid)) * dt;
E_batt_charge  = sum(max(0, -P_batt)) * dt;
E_batt_dischg  = sum(max(0, P_batt)) * dt;

% Biaya Listrik Tradisional (Tanpa PV & Tanpa Baterai)
cost_baseline_per_step = P_load .* tariff_import * dt;
cost_baseline_total    = sum(cost_baseline_per_step);

% Biaya Listrik dengan Smart Home Energy Management System
cost_import_per_step = max(0, P_grid) .* tariff_import * dt;
revenue_export_per_step = max(0, -P_grid) .* tariff_export * dt;
cost_shems_total     = sum(cost_import_per_step) - sum(revenue_export_per_step);

% Metrik Efisiensi
cost_savings_rp      = cost_baseline_total - cost_shems_total;
cost_savings_pct     = (cost_savings_rp / cost_baseline_total) * 100;
self_consumption_pct = ((E_pv_total - E_grid_export) / E_pv_total) * 100;
self_sufficiency_pct = ((E_load_total - E_grid_import) / E_load_total) * 100;

%% 5. TAMPILKAN RINGKASAN DI COMMAND WINDOW
fprintf('\n=======================================================\n');
fprintf('  RINGKASAN KINERJA SMART HOME ENERGY MANAGEMENT (24 JAM)\n');
fprintf('=======================================================\n');
fprintf('Total Konsumsi Beban Rumah   : %6.2f kWh\n', E_load_total);
fprintf('Total Produksi Energi Surya  : %6.2f kWh\n', E_pv_total);
fprintf('Energi Impor dari Grid PLN   : %6.2f kWh\n', E_grid_import);
fprintf('Energi Ekspor ke Grid PLN    : %6.2f kWh\n', E_grid_export);
fprintf('Energi Masuk Baterai (Chg)   : %6.2f kWh\n', E_batt_charge);
fprintf('Energi Keluar Baterai (Dis)  : %6.2f kWh\n', E_batt_dischg);
fprintf('-------------------------------------------------------\n');
fprintf('Tingkat Konsumsi Mandiri (Self-Consumption) : %5.1f %%\n', self_consumption_pct);
fprintf('Tingkat Kemandirian Energi (Self-Sufficiency): %5.1f %%\n', self_sufficiency_pct);
fprintf('-------------------------------------------------------\n');
fprintf('Biaya Listrik Tanpa SHEMS    : Rp %9.2f\n', cost_baseline_total);
fprintf('Biaya Listrik Dengan SHEMS   : Rp %9.2f\n', cost_shems_total);
fprintf('Total Penghematan Harian     : Rp %9.2f (%4.1f %%)\n', cost_savings_rp, cost_savings_pct);
fprintf('=======================================================\n\n');

%% 6. VISUALISASI HASIL SIMULASI (FIGURE PREVIEW)
fig = figure('Name', 'Smart Home Energy Management System', 'Color', 'w', 'Position', [100 80 1100 800]);

% Subplot 1: Keseimbangan Daya (Power Balance)
subplot(4, 1, 1);
plot(time, P_load, 'k-', 'LineWidth', 2.0, 'DisplayName', 'Beban Rumah (P_{Load})'); hold on;
plot(time, P_pv, 'Color', [0.93 0.69 0.13], 'LineWidth', 2.0, 'DisplayName', 'Solar PV (P_{PV})');
plot(time, P_batt, 'Color', [0.47 0.67 0.19], 'LineWidth', 1.8, 'DisplayName', 'Baterai BESS (P_{Batt})');
plot(time, P_grid, 'Color', [0 0.45 0.74], 'LineWidth', 1.8, 'DisplayName', 'Grid PLN (P_{Grid})');
yline(0, 'k--', 'Alpha', 0.4);
xlim([0 24]);
grid on;
title('Profil Keseimbangan Daya 24 Jam (Power Balance)', 'FontWeight', 'bold', 'FontSize', 11);
ylabel('Daya (kW)', 'FontWeight', 'bold');
legend('Location', 'northeast', 'NumColumns', 4);
set(gca, 'XTick', 0:2:24);

% Subplot 2: Status Pengisian Baterai (Battery SOC)
subplot(4, 1, 2);
plot(time, SOC, 'Color', [0.49 0.18 0.56], 'LineWidth', 2.2, 'DisplayName', 'Battery SOC (%)'); hold on;
yline(SOC_max, 'r--', ['Batas Max (' num2str(SOC_max) '%)'], 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
yline(SOC_min, 'r--', ['Batas Min (' num2str(SOC_min) '%)'], 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
ylim([10 105]);
xlim([0 24]);
grid on;
title('Dinamika State of Charge (SOC) Baterai BESS', 'FontWeight', 'bold', 'FontSize', 11);
ylabel('SOC (%)', 'FontWeight', 'bold');
legend('Location', 'southeast');
set(gca, 'XTick', 0:2:24);

% Subplot 3: Mode Operasi Sistem (Operating Modes)
subplot(4, 1, 3);
stairs(time, Mode, 'LineWidth', 1.8, 'Color', [0.85 0.33 0.1]);
ylim([0.5 5.5]);
xlim([0 24]);
yticks(1:5);
yticklabels({'PV Direct', 'Solar+Chg', 'Export Grid', 'Batt Dischg', 'Import Grid'});
grid on;
title('Mode Operasi HEMS Real-Time', 'FontWeight', 'bold', 'FontSize', 11);
ylabel('Mode Operasi', 'FontWeight', 'bold');
set(gca, 'XTick', 0:2:24);

% Subplot 4: Perbandingan Akumulasi Biaya Listrik (Cost Comparison)
subplot(4, 1, 4);
cum_cost_baseline = cumsum(cost_baseline_per_step);
cum_cost_shems    = cumsum(cost_import_per_step - revenue_export_per_step);
plot(time, cum_cost_baseline, 'r--', 'LineWidth', 2.0, 'DisplayName', 'Tanpa SHEMS (Grid Standar)'); hold on;
plot(time, cum_cost_shems, 'b-', 'LineWidth', 2.2, 'DisplayName', 'Dengan SHEMS (PV+BESS+Smart EMS)');
xlim([0 24]);
grid on;
title('Akumulasi Biaya Listrik Harian (Rupiah)', 'FontWeight', 'bold', 'FontSize', 11);
xlabel('Waktu (Jam)', 'FontWeight', 'bold');
ylabel('Biaya (Rp)', 'FontWeight', 'bold');
legend('Location', 'northwest');
set(gca, 'XTick', 0:2:24);

% Simpan gambar plot
saveas(fig, fullfile(pwd, 'shems_simulation_results.png'));
disp('Grafik simulasi berhasil disimpan sebagai shems_simulation_results.png');

% Otomatis ekspor telemetri JSON untuk integrasi Digital Twin / God's Eye View
if exist('shems_export_telemetry', 'file')
    disp('Mengekspor telemetri streaming...');
    shems_export_telemetry;
end
