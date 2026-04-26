function [secilen_iha, vuruldu_mu] = angajman_karar_merkezi(silah_idx, iha_x, iha_y, iha_aktif, kilitli_iha, vurus_menzili, muhimmat)
    secilen_iha = 0; % Başlangıçta seçilen bir hedef olmadığını varsayıyoruz.
    vuruldu_mu = false; % Başlangıçta vuruşun başarısız olduğunu varsayıyoruz.
    
    % Eğer bu silahın mühimmatı bitmişse hiç hesaplama yapma, fonksiyondan çık.
    if muhimmat(silah_idx) <= 0, return; end

    en_yakin_d = inf; % En yakın İHA'yı bulmak için başlangıç mesafesini sonsuz kabul et.
    
    % Tüm İHA'ları tek tek kontrol et.
    for i = 1:length(iha_aktif)
        if ~iha_aktif(i), continue; end % Eğer İHA zaten vurulmuşsa atla.
        
        % İHA ile gemi (merkez 0,0) arasındaki Pisagor mesafesini hesapla.
        d_iha = sqrt(iha_x(i)^2 + iha_y(i)^2);
        
        % Eğer İHA silahın menzili içindeyse;
        if d_iha <= vurus_menzili(silah_idx)
            is_targeted = false; % Bu İHA'ya başka bir silahın bakıp bakmadığını kontrol et.
            for s = 1:length(kilitli_iha)
                if s ~= silah_idx && kilitli_iha(s) == i
                    is_targeted = true; break; % Başka silah bu İHA ile meşgulse hedefi işaretle.
                end
            end
            
            % Eğer hedef boşta ise ve şu ana kadar bulunan en yakın hedef buysa seç.
            if ~is_targeted && d_iha < en_yakin_d
                en_yakin_d = d_iha;
                secilen_iha = i;
            end
        end
    end

    % Eğer bir hedef seçildiyse vuruş olasılığını hesapla.
    if secilen_iha ~= 0
        oran = en_yakin_d / vurus_menzili(silah_idx); % Hedef menzilin ne kadar içinde? (0: dibinde, 1: sınırda)
        
        % Silah tipine göre gerçekçi vuruş olasılıkları (Askeri karakteristiğe göre).
        switch silah_idx
            case 1 % CIWS: Yakına geldikçe karesel artan, çok yüksek vuruş gücü.
                max_p = 0.50; min_p = 0.05;
                v_olasiligi = max_p - (oran^1.5 * (max_p - min_p)); 
            case 2 % Savunma Füzesi: Uzun menzilde bile çok kararlı ve yüksek isabet.
                max_p = 0.92; min_p = 0.75;
                v_olasiligi = max_p - (oran * (max_p - min_p));
            case 3 % EH: Sadece sinyal bozar, fiziksel imha (hard-kill) olasılığı çok düşüktür.
                max_p = 0.1; min_p = 0.05;
                v_olasiligi = max_p - (oran * (max_p - min_p));
            case 4 % Ana Baş Top: Orta menzilli, standart topçu performansı.
                max_p = 0.65; min_p = 0.15;
                v_olasiligi = max_p - (oran * (max_p - min_p));
        end
        
        % Rastgele bir sayı üret, eğer vuruş olasılığından küçükse hedef imha edildi!
        if rand() <= v_olasiligi, vuruldu_mu = true; end
    end
end