function y = hems_controller_fcn(u)
% =========================================================================
% HEMS CONTROLLER FUNCTION FOR SIMULINK (INTERPRETED MATLAB FUNCTION)
% Input  u: [P_pv; P_load; SOC]
% Output y: [P_batt; P_grid; mode]
% =========================================================================

P_pv   = u(1);
P_load = u(2);
SOC    = u(3);

P_net = P_pv - P_load;
SOC_max = 95.0;
SOC_min = 20.0;
P_batt_max = 3.5;

if P_net >= 0
    % Surplus Daya Surya (P_pv >= P_load)
    if SOC < SOC_max
        P_chg = min(P_net, P_batt_max);
        P_batt = -P_chg; % Daya negatif = mengisi baterai
        P_grid = -(P_net - P_chg); % Kelebihan setelah baterai diekspor ke Grid
        if P_grid < -0.01
            mode = 3; % Ekspor ke Grid
        else
            mode = 2; % Solar menyuplai beban + mengisi baterai
        end
    else
        % Baterai sudah penuh (SOC >= SOC_max)
        P_batt = 0;
        P_grid = -P_net; % Seluruh surplus diekspor ke Grid
        mode = 3;
    end
else
    % Defisit Daya Surya (P_pv < P_load)
    P_def = abs(P_net);
    if SOC > SOC_min
        P_dis = min(P_def, P_batt_max);
        P_batt = P_dis; % Daya positif = mengosongkan baterai
        P_grid = P_def - P_dis; % Sisa defisit diambil dari Grid
        if P_grid > 0.05
            mode = 5; % Baterai + Impor Grid
        else
            mode = 4; % Baterai menutupi seluruh defisit
        end
    else
        % Baterai sudah mencapai batas minimum (SOC <= SOC_min)
        P_batt = 0;
        P_grid = P_def; % 100% defisit diimpor dari Grid
        mode = 5;
    end
end

y = [P_batt; P_grid; mode];
end
