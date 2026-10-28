%% =========================================================================
% SMART HOME ENERGY MANAGEMENT SYSTEM (SHEMS) - LIVE ANIMATED DASHBOARD
% Simulasi Real-Time Bergerak (Live Animation seperti di Reel Instagram)
% =========================================================================

clear; close all; clc;

% 1. Muat parameter sistem
shems_parameters;

%% 2. PRA-KALKULASI DINAMIKA SISTEM
P_batt = zeros(1, N);
P_grid = zeros(1, N);
SOC    = zeros(1, N);
Mode   = zeros(1, N);
SOC(1) = SOC_init;

for k = 1:N-1
    P_pv_now   = P_pv(k);
    P_load_now = P_load(k);
    P_net      = P_pv_now - P_load_now;
    soc_curr   = SOC(k);
    
    if P_net >= 0
        if soc_curr < SOC_max
            max_chg = (SOC_max - soc_curr) * E_batt_nom / (100 * dt * eta_chg);
            P_chg = min([P_net, P_batt_chg_max, max_chg]);
            P_batt(k) = -P_chg;
            P_grid(k) = -(P_net - P_chg);
            if P_grid(k) < -0.01
                Mode(k) = 3; % Ekspor Grid
            else
                Mode(k) = 2; % Solar charge Baterai
            end
        else
            P_batt(k) = 0;
            P_grid(k) = -P_net;
            Mode(k)   = 3; % Ekspor Full
        end
    else
        P_def = abs(P_net);
        if soc_curr > SOC_min
            max_dis = (soc_curr - SOC_min) * E_batt_nom * eta_dis / (100 * dt);
            P_dis = min([P_def, P_batt_dis_max, max_dis]);
            P_batt(k) = P_dis;
            P_grid(k) = P_def - P_dis;
            if P_grid(k) > 0.05
                Mode(k) = 5; % Baterai + Impor Grid
            else
                Mode(k) = 4; % Baterai Handle Defisit
            end
        else
            P_batt(k) = 0;
            P_grid(k) = P_def;
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

%% 3. MEMBUAT GUI DASHBOARD LIVE BERGERAK (DARK MODERN THEME)
fig = figure('Name', 'SHEMS Real-Time Live Animated Dashboard', ...
             'Color', [0.10 0.11 0.14], ...
             'Position', [80 50 1200 780], ...
             'NumberTitle', 'off');

% Header Banner
annotation('textbox', [0.03 0.92 0.55 0.06], ...
    'String', 'SMART HOME ENERGY MANAGEMENT SYSTEM (SHEMS)', ...
    'Color', [1 1 1], 'FontSize', 14, 'FontWeight', 'bold', ...
    'EdgeColor', 'none', 'BackgroundColor', 'none');

% Text Waktu Digital (Clock Display)
txt_clock = annotation('textbox', [0.60 0.92 0.18 0.06], ...
    'String', 'WAKTU: 00:00', ...
    'Color', [0.2 0.9 1.0], 'FontSize', 13, 'FontWeight', 'bold', ...
    'EdgeColor', [0.3 0.3 0.4], 'BackgroundColor', [0.15 0.16 0.20], ...
    'HorizontalAlignment', 'center');

% Text Mode Operasi Real-Time
txt_mode = annotation('textbox', [0.79 0.92 0.18 0.06], ...
    'String', 'MODE: INISIALISASI', ...
    'Color', [1.0 0.8 0.2], 'FontSize', 12, 'FontWeight', 'bold', ...
    'EdgeColor', [0.3 0.3 0.4], 'BackgroundColor', [0.15 0.16 0.20], ...
    'HorizontalAlignment', 'center');

% Subplot 1: Grafik Power Balance yang Berjalan (Animasi Titik Bergerak)
ax1 = subplot(3, 1, 1);
set(ax1, 'Color', [0.14 0.15 0.18], 'XColor', [0.7 0.7 0.7], 'YColor', [0.7 0.7 0.7]);
grid on; hold on;
set(ax1, 'GridColor', [0.3 0.3 0.35], 'GridAlpha', 0.6);
xlim([0 24]); ylim([-4.2 5.5]);
ylabel('Daya (kW)', 'Color', 'w', 'FontWeight', 'bold');
title('Real-Time Power Balance (Daya Listrik Bergerak)', 'Color', 'w', 'FontSize', 11);
set(ax1, 'XTick', 0:2:24);

h_load = animatedline('Color', [0.9 0.9 0.9], 'LineWidth', 2.2, 'DisplayName', 'Beban Rumah');
h_pv   = animatedline('Color', [1.0 0.78 0.0], 'LineWidth', 2.2, 'DisplayName', 'Solar PV');
h_batt = animatedline('Color', [0.3 0.85 0.4], 'LineWidth', 2.0, 'DisplayName', 'Baterai BESS');
h_grid = animatedline('Color', [0.2 0.6 1.0],  'LineWidth', 2.0, 'DisplayName', 'Grid PLN');
yline(0, 'Color', [0.5 0.5 0.5], 'LineStyle', '--');
legend('TextColor', 'w', 'Color', [0.18 0.19 0.23], 'EdgeColor', [0.3 0.3 0.4], 'Location', 'northeast', 'NumColumns', 4);

% Marker Titik Saat Ini (Head Cursor)
h_cursor1 = plot(0, 0, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');

% Subplot 2: Animasi State of Charge (SOC) Baterai
ax2 = subplot(3, 1, 2);
set(ax2, 'Color', [0.14 0.15 0.18], 'XColor', [0.7 0.7 0.7], 'YColor', [0.7 0.7 0.7]);
grid on; hold on;
set(ax2, 'GridColor', [0.3 0.3 0.35], 'GridAlpha', 0.6);
xlim([0 24]); ylim([10 105]);
ylabel('SOC (%)', 'Color', 'w', 'FontWeight', 'bold');
title('Dinamika Pengisian Baterai BESS Real-Time', 'Color', 'w', 'FontSize', 11);
set(ax2, 'XTick', 0:2:24);

h_soc = animatedline('Color', [0.8 0.3 1.0], 'LineWidth', 2.2, 'DisplayName', 'Battery SOC');
yline(SOC_max, 'r--', 'Max 95%', 'Color', [1 0.3 0.3], 'LabelHorizontalAlignment', 'left');
yline(SOC_min, 'r--', 'Min 20%', 'Color', [1 0.3 0.3], 'LabelHorizontalAlignment', 'left');
h_cursor2 = plot(0, SOC_init, 'mo', 'MarkerSize', 8, 'MarkerFaceColor', [0.8 0.3 1.0]);

% Subplot 3: Bar Meter Real-Time (Live Gauges)
ax3 = subplot(3, 1, 3);
set(ax3, 'Color', [0.14 0.15 0.18], 'XColor', 'w', 'YColor', [0.7 0.7 0.7]);
grid on; hold on;
bar_labels = {'Solar PV', 'Home Load', 'Battery Power', 'Grid Power', 'Battery SOC (%)'};
h_bars = bar(1:5, [0, 0, 0, 0, 0]);
h_bars.FaceColor = 'flat';
h_bars.CData(1,:) = [1.0 0.78 0.0];   % Kuning PV
h_bars.CData(2,:) = [0.9 0.9 0.9];    % Putih Beban
h_bars.CData(3,:) = [0.3 0.85 0.4];   % Hijau Baterai
h_bars.CData(4,:) = [0.2 0.6 1.0];    % Biru Grid
h_bars.CData(5,:) = [0.8 0.3 1.0];    % Ungu SOC
set(ax3, 'XTick', 1:5, 'XTickLabel', bar_labels, 'FontWeight', 'bold');
ylim([-4.5 105]);
title('Instantaneous Power & Storage Level (Live Meter)', 'Color', 'w', 'FontSize', 11);
ylabel('Nilai Aktual', 'Color', 'w', 'FontWeight', 'bold');

% Teks Nilai Numerik di Atas Bar
txt_bar_vals = text(1:5, [5 5 5 5 5], {'0 kW', '0 kW', '0 kW', '0 kW', '0 %'}, ...
    'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold', 'FontSize', 10);

%% 4. LOOP ANIMASI REAL-TIME (LIVE MOTION)
% Skip frame agar gerakan halus dan responsif (misal step setiap 4 menit)
step_skip = 4;
for k = 1:step_skip:N
    if ~ishghandle(fig)
        break; % Jika jendela ditutup user, hentikan animasi
    end
    
    t_curr = time(k);
    hours   = floor(t_curr);
    minutes = floor((t_curr - hours) * 60);
    
    % Update Waktu Digital
    set(txt_clock, 'String', sprintf('WAKTU: %02d:%02d WIB', hours, minutes));
    
    % Update Mode Operasi
    m_now = Mode(k);
    switch m_now
        case 2
            set(txt_mode, 'String', 'MODE: SOLAR + CHARGE', 'Color', [0.3 1.0 0.4]);
        case 3
            set(txt_mode, 'String', 'MODE: EKSPOR KE GRID', 'Color', [0.2 0.8 1.0]);
        case 4
            set(txt_mode, 'String', 'MODE: BATERAI DISCHARGE', 'Color', [1.0 0.7 0.2]);
        case 5
            set(txt_mode, 'String', 'MODE: IMPOR DARI GRID', 'Color', [1.0 0.3 0.3]);
        otherwise
            set(txt_mode, 'String', 'MODE: STANDBY', 'Color', [0.7 0.7 0.7]);
    end
    
    % Tambahkan titik ke garis animasi
    idx_range = max(1, k-step_skip+1):k;
    addpoints(h_load, time(idx_range), P_load(idx_range));
    addpoints(h_pv,   time(idx_range), P_pv(idx_range));
    addpoints(h_batt, time(idx_range), P_batt(idx_range));
    addpoints(h_grid, time(idx_range), P_grid(idx_range));
    addpoints(h_soc,  time(idx_range), SOC(idx_range));
    
    % Update Posisi Kursor Bergerak
    set(h_cursor1, 'XData', t_curr, 'YData', P_load(k));
    set(h_cursor2, 'XData', t_curr, 'YData', SOC(k));
    
    % Update Nilai Bar Meter
    vals = [P_pv(k), P_load(k), P_batt(k), P_grid(k), SOC(k)];
    set(h_bars, 'YData', vals);
    
    % Update Label Angka di Atas Bar
    txt_bar_vals(1).Position = [1, max(0.5, vals(1) + 2), 0];
    txt_bar_vals(1).String   = sprintf('%.2f kW', vals(1));
    
    txt_bar_vals(2).Position = [2, max(0.5, vals(2) + 2), 0];
    txt_bar_vals(2).String   = sprintf('%.2f kW', vals(2));
    
    txt_bar_vals(3).Position = [3, max(0.5, vals(3) + 2), 0];
    txt_bar_vals(3).String   = sprintf('%.2f kW', vals(3));
    
    txt_bar_vals(4).Position = [4, max(0.5, vals(4) + 2), 0];
    txt_bar_vals(4).String   = sprintf('%.2f kW', vals(4));
    
    txt_bar_vals(5).Position = [5, max(5, vals(5) + 4), 0];
    txt_bar_vals(5).String   = sprintf('%.1f %%', vals(5));
    
    % Render frame ke layar
    drawnow limitrate;
    pause(0.02); % Kecepatan animasi (bisa dipercepat/diperlambat)
end

disp('Animasi 24 jam selesai!');
