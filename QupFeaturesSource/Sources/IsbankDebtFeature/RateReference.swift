import Foundation

/// One month of TCMB ceiling rates for one file.
public struct MonthlyRateRow: Identifiable, Equatable, Sendable {
    public let id: String
    /// "Ağustos 2024 (1.08.2024)", plus any note the HTML carried inline.
    public let month: String
    /// Only file 2 is tiered; nil for the KMH file.
    public let tier: String?
    /// Azami akdi faiz, aylık.
    public let contractual: String
    /// Azami gecikme faizi, aylık.
    public let overdue: String
    /// What the bank actually charged — almost always unknown, because the
    /// Dosya Hesabı reports a single total interest figure with no breakdown.
    public let bankRate: String
    public let source: String
    /// True where the TCMB ceiling fell below the rate fixed at takip start,
    /// so an un-lowered rate would mean interest charged above the cap.
    public let isRisk: Bool

    public init(
        month: String,
        tier: String? = nil,
        contractual: String,
        overdue: String,
        bankRate: String,
        source: String,
        isRisk: Bool = false
    ) {
        self.id = month
        self.month = month
        self.tier = tier
        self.contractual = contractual
        self.overdue = overdue
        self.bankRate = bankRate
        self.source = source
        self.isRisk = isRisk
    }
}

/// The rate applied when each takip was opened, against the ceiling of the day.
public struct AppliedRateRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let file: String
    public let date: String
    public let debtKind: String
    public let monthlyRate: String
    public let annualRate: String
    public let ceiling: String
    public let verdict: String

    public init(
        file: String,
        date: String,
        debtKind: String,
        monthlyRate: String,
        annualRate: String,
        ceiling: String,
        verdict: String
    ) {
        self.id = file
        self.file = file
        self.date = date
        self.debtKind = debtKind
        self.monthlyRate = monthlyRate
        self.annualRate = annualRate
        self.ceiling = ceiling
        self.verdict = verdict
    }
}

/// A rule or caveat with its own sourcing note.
public struct ReferenceNote: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let source: String
    /// Whether this note cross-references the month-by-month rate tables.
    public let linksToRates: Bool

    public init(title: String, body: String, source: String, linksToRates: Bool = false) {
        self.id = title
        self.title = title
        self.body = body
        self.source = source
        self.linksToRates = linksToRates
    }
}

/// Verified figures behind the calculator, transcribed from the source page.
///
/// Every monthly rate here was read from TCMB's own PDF/HTML rather than a
/// summary, which is why each row carries its own source label.
public enum RateReference {
    // MARK: - 1. Rates actually applied at takip start

    public static let appliedRates: [AppliedRateRow] = [
        AppliedRateRow(
            file: "2024/162868",
            date: "15.08.2024",
            debtKind: "Ek Hesap / KMH gecikme faizi",
            monthlyRate: "%5,30",
            annualRate: "%63,60",
            ceiling: "KMH/nakit kullanım azami gecikme: %5,30/ay",
            verdict: "Tavanda — aşım yok"
        ),
        AppliedRateRow(
            file: "2024/234554",
            date: "14.10.2024",
            debtKind: "Kredi kartı gecikme faizi",
            monthlyRate: "%4,55",
            annualRate: "%54,60",
            ceiling: "Genel kart azami gecikme (kademe öncesi): %4,55/ay",
            verdict: "Tavanda — aşım yok"
        ),
    ]

    // MARK: - 2. Fixed fee rules (not interest)

    public static let feeRules: [ReferenceNote] = [
        ReferenceNote(
            title: "Tahsil Harcı kademeleri (492 sayılı Harçlar Kanunu, (1) Sayılı Tarife, B Bölümü)",
            body: """
            • Ödeme/icra emri tebliğinden sonra, hacizden evvel ödenen paralarda: %4,55
            • Maaş, ücret, gündelik ve sair hizmet gelirlerinin haczi suretiyle tahsil edilen paralarda \
            (bu dosyadaki durum — 18 kesintinin tamamı maaş haczi): %4,55 — ayrı bir kanun kademesi, \
            "hacizden evvel" kademesiyle aynı orana denk geliyor, aynı şey değil.
            • Hacizden sonra, satıştan önce ödenen paralarda: %9,10
            • Haczedilen/rehinli malın satışı yoluyla tahsilde: %11,38
            • Haricen (dosya dışı, doğrudan alacaklıya) tahsilde: yukarıdaki oranların yarısı uygulanır.
            """,
            source: """
            Dosya 162868'in Dosya Hesabı dökümünde her 18 "Yatan Para" satırının yanındaki 4.55 değeri, \
            tahsilatın tamamı maaş haczi yoluyla yapıldığı için doğru kademe. \
            Yerel kaynak: dosya-hesabi-1.txt, progress/12 §3. \
            Kanun tarifesi (web, 04.08.2026 doğrulandı): mevzuat.gov.tr 1.5.492.pdf, İmer Hukuk, Can Legal.
            """
        ),
        ReferenceNote(
            title: "Cezaevi (Yapı) Harcı — %2",
            body: """
            2548 sayılı Kanun m.1 uyarınca icra dairelerince tahsil olunan paraların %2'si, dosyanın hangi \
            aşamada olduğuna bakılmaksızın sabit oranda kesilir; devlete gider, iade edilmez.
            """,
            source: """
            ⚠️ Yeni araştırma bulgusu (04.08.2026): Kanunun lafzına göre bu harç alacaklıya yapılacak \
            ödemeden kesilmesi gereken bir kalemdir, borçludan ayrıca talep edilecek bir kalem değildir — \
            ancak uygulamada dosya hesaplarında borçlunun ödediği tutarın içinde gösterildiği de görülüyor \
            (progress/02'de 162868 için 5.108 TL). Kimin üzerine yüklendiği tartışmalı; D2 dilekçesiyle \
            netleştirilmeli. Kaynak: progress/02 §6 · Kırklareli Barosu, İçtihat Bilgi Bankası.
            """
        ),
        ReferenceNote(
            title: "BSMV ve KKDF",
            body: """
            Dosya Hesabı'nda ayrı kalemler olarak sabit tutarla geçiyor — oran değil, hesaplanmış nihai \
            tutar olarak verilmiş. 162868: BSMV 12.075,29 / KKDF 12.075,29. \
            234554: BSMV 5.112,50 / KKDF 5.112,50.
            """,
            source: "Kaynak: Dosya Hesabı dökümleri, progress/12."
        ),
        ReferenceNote(
            title: "Haricen kapamada tahsil harcı yarıya iner",
            body: """
            Borç icra dosyası üzerinden değil doğrudan avukatla anlaşarak kapatılırsa tahsil harcı oranı \
            yarı yarıya düşer — peşin kapama pazarlığında kullanılabilecek bir husus.
            """,
            source: "Kaynak: progress/02 §6, progress/03."
        ),
        ReferenceNote(
            title: "Vekâlet ücreti (AAÜT) — kısmen doğrulanabildi",
            body: """
            Bu dosyalardaki nispi vekâlet ücreti oranı (40.865,84 / 255.411,49 ≈ %16,0 ve \
            21.067,79 / 131.673,68 ≈ %16,0) takip tarihindeki 2024 Avukatlık Asgari Ücret Tarifesi'nin \
            genel nispi ücret kademeleriyle (~%15 bandı, 200.000 TL üzeri dilim) kabaca uyumlu görünüyor; \
            ancak icra dairesi takiplerine özgü kademeyi web araması tam doğrulayamadı — kesin teyit için \
            2024 AAÜT'nin resmî Resmî Gazete metni kontrol edilmeli.
            """,
            source: """
            Web araştırması (04.08.2026): 2024 AAÜT özeti — icra dairesi işlemleri için yalnızca \
            3.600 TL maktu asgari ücret net görüldü; nispi kademe tam teyit edilemedi.
            """
        ),
    ]

    // MARK: - 3. File 162868 (Ek Hesap / KMH) monthly ceilings

    private static let pdfPage2 = "PDF s.2"
    private static let pdfPage1 = "PDF s.1"
    private static let currentHTML = "guncel.html"
    private static let liveTCMB = "TCMB (canlı, 04.08.2026)"
    private static let unknown = "Bilinmiyor"
    private static let unknownRisk = "Bilinmiyor — düşürülmediyse fazla faiz riski"

    public static let file1Rates: [MonthlyRateRow] = [
        MonthlyRateRow(month: "Ağustos 2024 (1.08.2024) — takip başlangıcı 15.08.2024", contractual: "%5,00", overdue: "%5,30", bankRate: "%5,30 (Takip Talebi'nde sabit)", source: pdfPage2),
        MonthlyRateRow(month: "Eylül 2024 (1.09.2024)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage2),
        MonthlyRateRow(month: "Ekim 2024 (1.10.2024)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage2),
        MonthlyRateRow(month: "Kasım 2024 (1.11.2024)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Aralık 2024 (1.12.2024)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Ocak 2025 (1.01.2025)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Şubat 2025 (1.02.2025)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Mart 2025 (1.03.2025)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Nisan 2025 (1.04.2025)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Mayıs 2025 (1.05.2025)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Haziran 2025 (1.06.2025)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Temmuz 2025 (1.07.2025)", contractual: "%5,00", overdue: "%5,30", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Ağustos 2025 (1.08.2025)", contractual: "%4,75", overdue: "%5,05", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Eylül 2025 (1.09.2025)", contractual: "%4,75", overdue: "%5,05", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Ekim 2025 (1.10.2025)", contractual: "%4,50", overdue: "%4,80", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Kasım 2025 (1.11.2025)", contractual: "%4,50", overdue: "%4,80", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Aralık 2025 (1.12.2025)", contractual: "%4,50", overdue: "%4,80", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Ocak 2026 (1.01.2026) — eşikler 30 bin/180 bin TL oldu", contractual: "%4,25", overdue: "%4,55", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Şubat 2026 (1.02.2026)", contractual: "%4,25", overdue: "%4,55", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Mart 2026 (1.03.2026)", contractual: "%4,25", overdue: "%4,55", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Nisan 2026 (1.04.2026)", contractual: "%4,25", overdue: "%4,55", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Mayıs 2026 (1.05.2026)", contractual: "%4,25", overdue: "%4,55", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Haziran 2026 (1.06.2026)", contractual: "%4,25", overdue: "%4,55", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Temmuz 2026 (1.07.2026)", contractual: "%4,25", overdue: "%4,55", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Ağustos 2026 (1.08.2026) — web'den doğrulandı, değişiklik yok", contractual: "%4,25", overdue: "%4,55", bankRate: unknownRisk, source: liveTCMB, isRisk: true),
    ]

    // MARK: - 4. File 234554 (kredi kartı) monthly ceilings

    private static let preTier = "Kademe öncesi / genel"
    private static let tierMid = "25.000–150.000 TL"
    private static let tierMidRaised = "30.000–180.000 TL"

    public static let file2Rates: [MonthlyRateRow] = [
        MonthlyRateRow(month: "Ağustos 2024 (1.08.2024)", tier: preTier, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage2),
        MonthlyRateRow(month: "Eylül 2024 (1.09.2024)", tier: preTier, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage2),
        MonthlyRateRow(month: "Ekim 2024 (1.10.2024) — takip başlangıcı 14.10.2024", tier: preTier, contractual: "%4,25", overdue: "%4,55", bankRate: "%4,55 (Takip Talebi'nde sabit)", source: pdfPage2),
        MonthlyRateRow(month: "Kasım 2024 (1.11.2024) — kademeli sistem başladı", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Aralık 2024 (1.12.2024)", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Ocak 2025 (1.01.2025)", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Şubat 2025 (1.02.2025)", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Mart 2025 (1.03.2025)", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Nisan 2025 (1.04.2025)", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Mayıs 2025 (1.05.2025)", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Haziran 2025 (1.06.2025)", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Temmuz 2025 (1.07.2025)", tier: tierMid, contractual: "%4,25", overdue: "%4,55", bankRate: unknown, source: pdfPage1),
        MonthlyRateRow(month: "Ağustos 2025 (1.08.2025)", tier: tierMid, contractual: "%4,00", overdue: "%4,30", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Eylül 2025 (1.09.2025)", tier: tierMid, contractual: "%4,00", overdue: "%4,30", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Ekim 2025 (1.10.2025)", tier: tierMid, contractual: "%4,00", overdue: "%4,30", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Kasım 2025 (1.11.2025)", tier: tierMid, contractual: "%4,00", overdue: "%4,30", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Aralık 2025 (1.12.2025)", tier: tierMid, contractual: "%4,00", overdue: "%4,30", bankRate: unknownRisk, source: pdfPage1, isRisk: true),
        MonthlyRateRow(month: "Ocak 2026 (1.01.2026) — eşik 30.000–180.000 TL oldu", tier: tierMidRaised, contractual: "%3,75", overdue: "%4,05", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Şubat 2026 (1.02.2026)", tier: tierMidRaised, contractual: "%3,75", overdue: "%4,05", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Mart 2026 (1.03.2026)", tier: tierMidRaised, contractual: "%3,75", overdue: "%4,05", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Nisan 2026 (1.04.2026)", tier: tierMidRaised, contractual: "%3,75", overdue: "%4,05", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Mayıs 2026 (1.05.2026)", tier: tierMidRaised, contractual: "%3,75", overdue: "%4,05", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Haziran 2026 (1.06.2026)", tier: tierMidRaised, contractual: "%3,75", overdue: "%4,05", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Temmuz 2026 (1.07.2026)", tier: tierMidRaised, contractual: "%3,75", overdue: "%4,05", bankRate: unknownRisk, source: currentHTML, isRisk: true),
        MonthlyRateRow(month: "Ağustos 2026 (1.08.2026) — web'den doğrulandı, değişiklik yok", tier: tierMidRaised, contractual: "%3,75", overdue: "%4,05", bankRate: unknownRisk, source: liveTCMB, isRisk: true),
    ]

    public static let futureMonthsNote = """
    Eylül 2026 ve sonrası: TCMB tarafından henüz ilan edilmedi (yerel PDF kopyası 09.07.2026'da indirildi; \
    Ağustos 2026 satırı 04.08.2026'da TCMB'nin canlı sayfasından ayrıca doğrulandı).
    """

    // MARK: - 5. Restructuring reference

    public static let restructuringRules: [String] = [
        """
        BDDK kararlarına (10972 – 26.09.2024, 11240 – 10.07.2025, 11366 – 29.01.2026) göre kredi kartı borcu \
        yapılandırılırsa uygulanacak aylık akdi faiz oranı aylık referans oran ile sınırlıdır.
        """,
        """
        Güncel resmî tabloda aylık referans oran: %3,11 → basit yıllık karşılığı %3,11 × 12 = %37,32 \
        (bileşik yıllık farklı çıkar; bu yalnız basit çarpım).
        """,
        """
        Bu oran, "yıllık %60" olarak notlanan gecikme/temerrüt faiziyle KARIŞTIRILMAMALI — biri yapılandırma \
        teklifi oranı, diğeri işlemiş gecikme faizidir.
        """,
    ]

    // MARK: - Items deliberately left out of the total

    public static let openQuestions: [ReferenceNote] = [
        ReferenceNote(
            title: "Faiz tavanı aşımı (olası)",
            body: """
            Dosya 162868 faiz oranı takip talebinde %63,60/yıl (%5,30/ay) ile başlatılmış; bu, 2024 KMH için \
            TCMB azami oranıydı. TCMB tavanı Ağustos 2025 – Ocak 2026 arasında kademeli olarak düştü \
            (%5,05 → %4,80 → %4,55). Banka bu düşüşleri uygulamadıysa fazla faiz tahsil edilmiş olabilir — \
            tutarı dönemsel faiz tablosu/bilirkişi hesabı olmadan kesin belirlenemediği için bu hesaplamaya \
            dahil edilmedi.
            """,
            source: "Kaynak: progress/12 §3 · itiraz dilekçesi taslağı: D2 — Dosya Hesabı ve Faize İtiraz",
            linksToRates: true
        ),
        ReferenceNote(
            title: "İİK 83 — maaştan çifte kesinti",
            body: """
            2026 itibarıyla bazı aylarda maaş haczi (~19.374 TL) ile banka takası (~14.531 TL) aynı ay üst üste \
            kesilmiş; net maaşın ~%44'ü gitmiş görünüyor (yasal sınır %25). Bu bir usulsüzlük iddiasıdır, borç \
            tutarını değiştirmez ama iade/mahsup talebine konu olabilir.
            """,
            source: """
            Kaynak: progress/02 §4 · şikâyet dilekçesi taslağı: D1 — İcra Mahkemesi Şikâyeti (Maaş Haczi) · \
            onay/reddiyat: D0 — Muvafakatten Dönme / 1/4 Sınırı Talebi
            """
        ),
        ReferenceNote(
            title: "Vekâlet ücreti tekrarı",
            body: """
            Aynı borç için iki ayrı icra dosyası açıldığından vekâlet ücreti iki kez \
            (40.865,84 + 21.067,79 = 61.933,63 TL) hesaplanmış. Web araştırması (04.08.2026): nispi oran \
            (~%16,0, her iki dosyada da aynı) 2024 AAÜT'nin genel nispi ücret bandıyla (~%15, 200.000 TL üzeri \
            dilim) kabaca uyumlu görünüyor, ama icra dairesi işlemlerine özgü kademe web'den tam teyit \
            edilemedi — resmî tarife metniyle kesinleştirilmeli.
            """,
            source: "Kaynak: Dosya Hesabı 162868 (40.865,84 TL), Dosya Hesabı 234554 (21.067,79 TL) · web: 2024 AAÜT özeti",
            linksToRates: true
        ),
        ReferenceNote(
            title: "Cezaevi harcının kimden kesildiği (yeni bulgu)",
            body: """
            2548 sayılı Kanun'a göre %2'lik cezaevi yapı harcı, kanunun lafzına göre alacaklıya ödenecek \
            tutardan kesilmesi gereken bir kalem; borçludan ayrıca tahsil edilecek bir kalem olarak \
            düzenlenmemiş. Ancak Dosya 162868'in harç listesinde 5.108 TL olarak borçlunun ödemesi içinde \
            gösteriliyor. Kimin üzerine yüklendiği tartışmalı ve borç tutarını etkileyebilir; kesin sonuç \
            dosyaya özgü inceleme + Yargıtay içtihadı karşılaştırması gerektirdiği için dahil edilmedi.
            """,
            source: "Kaynak: progress/02 §6 · web (04.08.2026): Kırklareli Barosu, İçtihat Bilgi Bankası",
            linksToRates: true
        ),
        ReferenceNote(
            title: "Mahsup itirazı riski",
            body: """
            Banka/avukat, TAKAS ve elden ödemelerin borca zaten mahsup edildiğini ancak dosya bakiyesine \
            yansıtılmadığını iddia edebilir — bu durumda "gerçek borç" bu sayfadaki tutar değil, resmî bakiye \
            (551.981,99 TL) olabilir. Kesin sonuç için yazılı mahsup dökümü istenmelidir (planlanan "D6" \
            dilekçesi — henüz kaleme alınmadı).
            """,
            source: "Kaynak: progress/12 §2 · progress/10 §4"
        ),
    ]

    // MARK: - Payment provenance

    public static let takasSource = """
    Kaynak: odeme-dogrulama-listesi.md §2 — hesap 1155 + 1149 toplamı · birincil belgeler: \
    11550676387 Hesap Özeti (1155), 11490609445 Hesap Özeti (1149)
    """

    public static let fibaSource = """
    Kaynak: odeme-dogrulama-listesi.md §3 · birincil belge: Fibabanka_Hesap Hareketleri.pdf · \
    e-dekontlar: 06.02.2025, 14.03.2025, 09.04.2025
    """

    public static let nextVerificationStep = """
    Bu tablo TCMB'nin ilan ettiği tavan oranları gösterir; bankanın her ayda fiilen hangi oranı işlettiğini \
    göstermez (Dosya Hesabı yalnız toplam faiz veriyor). Kesin tespit için icra dosyasından dönemsel/aylık \
    faiz hesap tablosu (veya bilirkişi raporu) istenmelidir — bkz. D6 dilekçesi ve progress/12 §3.
    """
}
