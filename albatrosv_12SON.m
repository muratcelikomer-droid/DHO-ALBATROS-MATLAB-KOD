%% EFES-2026 - ALBATROS V17 (SATIR SATIR AÇIKLAMALI)
clear; clc; close all; % Belleği temizle, komut satırını boşalt ve açık pencereleri kapat.

%% --- 1. PARAMETRELER ---
nIha = randi([35, 50]); % Simülasyona 35 ile 50 arasında rastgele sayıda İHA ekle.
gemi_pos = [0,0]; gemi_aktif = true; % Gemiyi merkeze koy ve başlangıçta "sağlam" yap.
iha_hiz_ms = 15 + rand(1, nIha) * 5; % İHA'lara 15-20 m/s arası rastgele hızlar tanımla.
hiz_faktor = 0.012; % Simülasyonun akış hızını (delta time gibi) belirleyen katsayı.
iha_aktif = true(1, nIha); % Tüm İHA'ları başlangıçta "canlı" olarak işaretle.

% İHA'ların başlangıç konumlarını (kutupsal koordinatlarla) belirle.
mesafe = 150 + rand(1, nIha) * 50; % Gemiden 220-320 birim uzakta başlasınlar.
aci = linspace(0, 2*pi, nIha) + rand(1, nIha); % İHA'ları gemi etrafına dairesel dağıt.
iha_x = mesafe .* cos(aci); % Kutupsal koordinatı Kartezyen X'e çevir.
iha_y = mesafe .* sin(aci); % Kutupsal koordinatı Kartezyen Y'ye çevir.

% Silah Sistemleri Teknik Tanımlamaları
vurus_menzili = [3, 15, 22, 10]*10; % CIWS, Füze, EH ve Top'un erişim mesafeleri.
silah_renk_tex = {'green', 'yellow', 'cyan', 'magenta'}; % Panelde görünecek renk isimleri.
silah_renk_matlab = {'g', 'y', 'c', 'm'}; % Grafiklerde kullanılacak renk kodları.
silah_isimler = {'CIWS Topu', 'Savunma Fuzesi', 'Elektronik Harp', 'Ana Baş Top'};
muhimmat = [250, 20, 1000000, 20]; % Başlangıç mühimmat sayıları (EH sınırsız gibi).
ates_hizi =[2, 60, 15, 25]; % İki atış arasındaki bekleme süresi (Düşük sayı = Hızlı atış).

% Angajman ve Log Yönetimi
maks_angajman_suresi = [6, 25, 10, 10]; % Bir İHA vurulamazsa kaç döngü sonra kilit kırılsın?
angajman_baslangic_zamani = zeros(1, 4); % Her silahın kilitlendiği anı kaydetmek için.
kilitli_iha = zeros(1, 4); % Silahların şu an hangi İHA'ya baktığını tutan dizi.
son_ates_zamani = zeros(1, 4); % Tekrar atış yapabilmek için gereken zaman takibi.
vurus_log = {}; % Gerçekleşen olayları (vuruş, çarpma vb.) kaydeden liste.

%% --- 2. GRAFİK EKRANI ---
figure('Color','k','Name','ALBATROS V17','Units','normalized','Position',[0.05 0.05 0.9 0.85]);
hold on; axis equal; grid on; % Koordinatları sabitle ve ızgarayı aç.
set(gca,'Color',[0 0.01 0],'XColor','g','YColor','g','GridAlpha',0.1); % Radar efekti için siyah-yeşil tema.
xlim([-350 650]); ylim([-350 350]); % Ekran sınırlarını belirle.

% Menzil Halkalarını Çiz (Radar ekranındaki dairesel çizgiler)
th = linspace(0, 2*pi, 100);
for j=1:4, plot(vurus_menzili(j)*cos(th), vurus_menzili(j)*sin(th), 'Color', silah_renk_matlab{j}, 'LineStyle', '--', 'LineWidth', 0.5); end

% Gemi Görselini Oluştur (Çokgen dolgu ile)
g_x = [0 2 3 3 2 -2 -3 -3 -2 0]*1.8; g_y = [12 8 4 -6 -10 -10 -6 4 8 12]*1.8;
hGemi = fill(g_x, g_y, [0.4 0.4 0.5], 'EdgeColor', 'w'); % Gri gövdeli beyaz kenarlı gemi.

% İHA ve Lazer (Ateş) Objelerini Başlat (Henüz koordinatları yok)
hIha = gobjects(1, nIha);
for i=1:nIha, hIha(i) = fill(NaN, NaN, 'r', 'EdgeColor', 'r'); end
hLazer = gobjects(1, 4);
for j=1:4, hLazer(j) = plot(NaN, NaN, 'Color', silah_renk_matlab{j}, 'LineWidth', 2); end

% Metin Panellerini Konumlandır (Sağ taraftaki bilgi ekranı)
hPanel = text(380, 320, '', 'Color', 'w', 'FontSize', 10, 'FontName', 'Consolas', 'VerticalAlignment', 'top', 'Interpreter', 'tex');
hLogPanel = text(380, 140, '', 'Color', 'w', 'FontSize', 8, 'FontName', 'Consolas', 'VerticalAlignment', 'top', 'Interpreter', 'tex');

%% --- 3. ANA DÖNGÜ (Simülasyonun Kalbi) ---
t = 0; % Zaman sayacını sıfırla.
while any(iha_aktif) % Canlı İHA kaldığı sürece döngüye devam et.
    t = t + 1; % Her adımda zamanı bir birim artır.
    
    % --- PANEL GÜNCELLEME ---
    panel_txt = '\bf--- SISTEM DURUMU (V17) --- \rm \newline';
    st_msg = '\color{green}SAVUNMA AKTIF'; if ~gemi_aktif, st_msg = '\color{red}SISTEMLER CEVRIMDISI'; end
    panel_txt = [panel_txt, st_msg, ' \newline'];
    for j=1:4
        m_str = sprintf('%.0f', muhimmat(j)); if (muhimmat(j)<=0 && j~=3), m_str='BITTI'; end
        panel_txt = [panel_txt, sprintf('\\color{%s} ■ %-16s \\color{white}: %s \\newline', silah_renk_tex{j}, silah_isimler{j}, m_str)];
    end
    set(hPanel, 'String', panel_txt); % Bilgileri ekrana yaz.

    % --- LOG PANELİ GÜNCELLEME ---
    log_txt = '\bf--- VURUS GUNLUGU --- \rm \newline';
    bas = max(1, length(vurus_log) - 24); % Sadece son 24 olayı göster (ekran taşmasın).
    for l = bas:length(vurus_log), log_txt = [log_txt, vurus_log{l}, ' \newline']; end
    set(hLogPanel, 'String', log_txt);

    % --- İHA HAREKETLERİ ---
    for i=1:nIha
        if ~iha_aktif(i), continue; end % Ölü İHA'ları hesaplama.
        dx = -iha_x(i); dy = -iha_y(i); % Hedef (0,0) noktasına olan vektörü hesapla.
        dist = sqrt(dx^2 + dy^2); angle = atan2(dy, dx); % Mesafe ve gidiş açısını bul.
        
        % İHA'yı merkeze (gemiye) doğru bir adım ilerlet.
        iha_x(i) = iha_x(i) + cos(angle)*iha_hiz_ms(i)*hiz_faktor;
        iha_y(i) = iha_y(i) + sin(angle)*iha_hiz_ms(i)*hiz_faktor;
        
        % İHA'nın görselini (üçgen formunu) yeni konumuna göre döndür ve çiz.
        set(hIha(i), 'XData', [0 3 0 -3]*cos(angle-pi/2) + iha_x(i), 'YData', [5 -2 0 -2]*sin(angle-pi/2) + iha_y(i));
        
        % Eğer İHA gemiye çok yaklaşırsa (çarpışma);
        if dist < 12
            if gemi_aktif, gemi_aktif = false; set(hGemi, 'FaceColor', [0.7 0 0]); end % Gemi vuruldu!
            iha_aktif(i) = false; if isgraphics(hIha(i)), delete(hIha(i)); end % İHA kendini imha etti.
            vurus_log{end+1} = '\color{red} [!] GEMIYE DARBE! SISTEMLER KAPALI'; % Loga işle.
        end
    end
    
    % --- ANGAJMAN (Saldırı Savunma Mantığı) ---
    if gemi_aktif % Sadece gemi sağlamsa ateş edebilir.
        for j=1:4 % 4 farklı silah sistemi için;
            % Karar merkezine danış: Hangi İHA'ya ateş edeyim? Vurabilir miyim?
            [hedef, vurus_basarili] = angajman_karar_merkezi(j, iha_x, iha_y, iha_aktif, kilitli_iha, vurus_menzili, muhimmat);
            
            % Eğer silah yeni bir hedefe kilitlendiyse kronometreyi başlat.
            if hedef ~= 0 && kilitli_iha(j) ~= hedef, angajman_baslangic_zamani(j) = t; end
            kilitli_iha(j) = hedef; % Mevcut kilit durumunu güncelle.

            if hedef ~= 0 % Eğer bir hedef varsa;
                % Zaman aşımı kontrolü (Silah bir hedefe çok uzun süre takılıp kalmamalı).
                if (t - angajman_baslangic_zamani(j)) > maks_angajman_suresi(j)
                    vurus_log{end+1} = sprintf('\\color{white} [PAS] %s: Hedef Atlandi', silah_isimler{j});
                    kilitli_iha(j) = 0; set(hLazer(j), 'Visible', 'off'); continue;
                end

                % Silah ile İHA arasındaki lazer çizgisini (ateş hattı) göster.
                set(hLazer(j), 'XData', [0, iha_x(hedef)], 'YData', [0, iha_y(hedef)], 'Visible', 'on');
                
                % Silahın ateş hızı dolduysa mermiyi/füzeyi ateşle.
                if t - son_ates_zamani(j) >= ates_hizi(j)
                    son_ates_zamani(j) = t; % Son ateş zamanını güncelle.
                    muhimmat(j) = muhimmat(j) - 1; % Mühimmatı bir birim azalt.
                    
                    % Eğer karar merkezi "vurdun" dediyse;
                    if vurus_basarili
                        vurus_log{end+1} = sprintf('\\color{%s} ID:%d Imha (%s)', silah_renk_tex{j}, hedef, silah_isimler{j});
                        iha_aktif(hedef) = false; % İHA'yı öldür.
                        if isgraphics(hIha(hedef)), delete(hIha(hedef)); end % Görseli sil.
                        kilitli_iha(j) = 0; set(hLazer(j), 'Visible', 'off'); % Silahı boşa çıkar.
                    end
                end
            else
                set(hLazer(j), 'Visible', 'off'); % Hedef yoksa ateşi kes.
            end
        end
    end
    drawnow; % Grafik ekranını her döngüde tazele.
end % Ana döngü sonu.