# SHEMS Simulation

Simulasi pendidikan manajemen energi rumah menggunakan MATLAB dan Simulink. Model memakai PV 5 kWp, baterai 10 kWh, dan profil beban sintetis selama 24 jam. Pengendali memilih pengisian baterai, pengosongan baterai, impor, dan ekspor jaringan berdasarkan daya dan SoC.

Jalankan `shems_simulation` untuk simulasi numerik dan grafik. Jalankan `shems_export_telemetry` untuk membuat JSON telemetri sintetis. Jalankan `build_shems_simulink` untuk membangun ulang `SHEMS_Model.slx`. Jalankan `verify` untuk pemeriksaan numerik dan kasus batas pengendali. MATLAB diperlukan. Model blok memerlukan Simulink.

Jalankan `python verify_saved.py` untuk memeriksa konsistensi telemetri yang tersimpan tanpa MATLAB. Pemeriksaan ini tidak menjalankan ulang model MATLAB atau Simulink.

Tarif impor dan ekspor merupakan asumsi skenario. Angka penghematan tidak mewakili tarif PLN yang berlaku atau hasil pengukuran rumah. Profil PV dan baterai belum dikalibrasi terhadap perangkat fisik. Pengendali Simulink memakai model sederhana yang berbeda dari pembatas energi per langkah pada simulasi numerik. Sampel telemetri terakhir menahan keluaran pengendali dari langkah sebelumnya.

Proyek mengadaptasi konsep video Smart Home Energy Management System Using MATLAB Simulink oleh @matlabsolutions. Implementasi lokal memakai bantuan AI. Folder cache Simulink, log mesin, dan konfigurasi agen tidak disertakan.
