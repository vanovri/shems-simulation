%% =========================================================================
% SMART HOME ENERGY MANAGEMENT SYSTEM (SHEMS) - PARAMETERS CONFIGURATION
% Sesuai dengan referensi arsitektur MATLAB Simulink (@matlabsolutions)
% =========================================================================

clear; clc;

%% 1. PENGATURAN WAKTU SIMULASI
% Simulasi 24 Jam dengan resolusi 1 menit (dt = 1/60 jam)
dt = 1/60;                      % Step size dalam jam
time = 0:dt:24;                 % Vektor waktu dari 00:00 sampai 24:00
N = length(time);

%% 2. SPESIFIKASI SISTEM SOLAR PV (PHOTOVOLTAIC)
P_pv_rated = 5.0;               % Kapasitas puncak PV (kWp)
eta_inverter = 0.96;            % Efisiensi Inverter DC-AC

% Profil Radiasi Surya 24 Jam (Model Lonceng Matahari Khatulistiwa/Tropis)
% Sinar matahari mulai jam 06:00, puncak jam 12:00, terbenam jam 18:00
G_peak = 1000;                  % W/m^2 (Peak Irradiance)
irradiance = zeros(1, N);
for k = 1:N
    t_hour = time(k);
    if t_hour >= 6 && t_hour <= 18
        irradiance(k) = G_peak * sin(pi * (t_hour - 6) / 12)^1.5;
    else
        irradiance(k) = 0;
    end
end
% Daya PV aktual (kW)
P_pv = (irradiance / G_peak) * P_pv_rated * eta_inverter;

%% 3. SPESIFIKASI SISTEM BATERAI (BESS - LITHIUM-ION)
E_batt_nom = 10.0;              % Kapasitas Nominal Baterai (kWh)
SOC_min = 20.0;                 % Batas Minimum SOC (%)
SOC_max = 95.0;                 % Batas Maksimum SOC (%)
SOC_init = 50.0;                % SOC Awal saat jam 00:00 (%)
P_batt_chg_max = 3.5;           % Daya Maksimum Pengisian (kW)
P_batt_dis_max = 3.5;           % Daya Maksimum Pengosongan (kW)
eta_chg = 0.95;                 % Efisiensi Pengisian (Charging Efficiency)
eta_dis = 0.95;                 % Efisiensi Pengosongan (Discharging Efficiency)

%% 4. PROFIL BEBAN RUMAH TANGGA 24 JAM (HOME LOAD PROFILE)
% Terdiri dari Base Load, Puncak Pagi, Puncak Siang, dan Beban Puncak Malam
P_load = zeros(1, N);
for k = 1:N
    t_hour = time(k);
    % Base load (Kulkas, standby router, sensor): ~0.35 kW
    base_load = 0.35;
    
    % Aktivitas Pagi (06:00 - 09:00: Pompa air, water heater, rice cooker, lampu)
    morning_peak = 2.2 * exp(-0.5 * ((t_hour - 7.5)/0.8)^2);
    
    % Aktivitas Siang (11:30 - 14:00: AC siang, microwave, TV)
    midday_load = 1.4 * exp(-0.5 * ((t_hour - 12.8)/1.0)^2);
    
    % Beban Puncak Malam (17:30 - 22:30: Penerangan penuh, AC malam, TV, hiburan)
    evening_peak = 3.6 * exp(-0.5 * ((t_hour - 19.5)/1.4)^2);
    
    % Beban Larut Malam (23:00 - 05:00: AC kamar tidur 0.6 kW)
    if t_hour >= 23 || t_hour < 6
        night_ac = 0.65;
    else
        night_ac = 0.0;
    end
    
    % Fluktuasi acak realistis (+/- 5%)
    noise = 0.05 * sin(2*pi*t_hour*4);
    
    P_load(k) = max(0.2, base_load + morning_peak + midday_load + evening_peak + night_ac + noise);
end

%% 5. STRUKTUR TARIF LISTRIK (TIME-OF-USE / TOU TARIFF PLN)
% Satuan: Rupiah per kWh (Rp/kWh)
tariff_import = zeros(1, N);
tariff_export = zeros(1, N);
for k = 1:N
    t_hour = time(k);
    if t_hour >= 17 && t_hour <= 22
        % Beban Puncak (WBP - Waktu Beban Puncak)
        tariff_import(k) = 2200; 
    elseif t_hour >= 22 || t_hour < 6
        % Luar Beban Puncak Malam (Off-Peak)
        tariff_import(k) = 1150; 
    else
        % Siang Hari (Shoulder Peak)
        tariff_import(k) = 1444; 
    end
    % Kebijakan Net Metering / Ekspor ke Grid (biasanya ~75% - 100% tarif normal)
    tariff_export(k) = 1100;
end

disp('Parameter SHEMS berhasil dimuat ke workspace!');
