/// Every piece of text the window shows, in one language; the Mac version of installer/Strings.cs.
struct Strings {
    // Uzbek text uses today's standard Latin spelling (oʻ, gʻ with U+02BB), which every reader knows.
    static let uzbek = Strings(
        languageName: "Oʻzbekcha",
        windowTitle: "Oʻzbek lotin 2026 klaviaturasini oʻrnatish",
        heading: "Klaviaturani tanlang",
        intro: "Uchala klaviatura ham 2026-yilgi oʻzbek lotin alifbosidagi ö, ş, ğ, ç harflarini va ʼ belgisini yozadi. "
            + "Farqi faqat shu harflar qaysi tugmalarda turganida. Oʻzingizga yoqqanini tanlang. Keyinroq boshqasini ham oʻrnatishingiz mumkin.",
        layouts: [
            "Uzbek Latin 2026 (Classic)": ("Klassik", "Barcha tugmalar US klaviaturadagi joyida qoladi. ö ş ğ ç harflari Option + O, S, G, C bilan yoziladi."),
            "Uzbek Latin 2026 (Direct)": ("Toʻgʻridan-toʻgʻri", "ö ş ğ harflari [ ; ' tugmalarida, ç esa C tugmasida. Oddiy c harfi Option + C bilan yoziladi."),
            "Uzbek Latin 2026 (Turkish-style)": ("Turkcha uslub", "ö ş ğ harflari [ ; ' tugmalarida, ç esa vergul tugmasida. Vergul \\ tugmasiga koʻchadi."),
        ],
        legendShift: "Shift",
        legendOptionShift: "Option+Shift",
        legendKey: "Tugma",
        legendOption: "Option",
        legendUzbekLetter: "Oʻzbek harfi",
        legendChanged: "US klaviaturadan farq qiladi",
        legendOptionKey: "Option (⌥) — Windowsdagi AltGr",
        otherOptionCharacters: "Option bilan yoziladigan boshqa belgilar (– — … € va hokazo) Macning U.S. klaviaturasidagidek.",
        badge: "Oʻrnatilgan",
        installButton: { _ in "Oʻrnatish" },
        installedButton: "Oʻrnatilgan",
        removeButton: { _ in "Oʻchirish" },
        afterInstallHint: "Oʻrnatilgan klaviaturalar orasida 🌐 yoki Control + Space bilan almashasiz.",
        installedNow: { "\($0) oʻrnatildi va yoqildi. Menyu satridagi UZ belgisi, 🌐 yoki Control + Space bilan unga oʻtasiz." },
        removed: { "\($0) oʻchirildi." },
        removeInSettings: { "Ochilgan System Settings oynasida Text Input boʻlimidagi Input Sources yonidagi Edit… ni bosing, \($0) ni tanlab, − ni bosing. Keyin shu oynaga qayting." },
        failed: { "Bajarib boʻlmadi: \($0)" },
        missingFiles: "Dasturning ichidagi klaviatura fayllari topilmadi. Dasturni qaytadan yuklab oling."
    )

    static let english = Strings(
        languageName: "English",
        windowTitle: "Uzbek Latin 2026 Keyboard Setup",
        heading: "Choose your keyboard",
        intro: "All three keyboards type the Uzbek Latin 2026 letters ö, ş, ğ, ç and the ʼ sign. "
            + "They differ only in which keys those letters are on. Pick the one you like. You can install another one later.",
        layouts: [
            "Uzbek Latin 2026 (Classic)": ("Classic", "Every key stays where it is on a US keyboard. Type ö ş ğ ç with Option + O, S, G, C."),
            "Uzbek Latin 2026 (Direct)": ("Direct", "ö ş ğ on the [ ; ' keys and ç on the C key. Plain c is Option + C."),
            "Uzbek Latin 2026 (Turkish-style)": ("Turkish-style", "ö ş ğ on the [ ; ' keys and ç on the comma key. Comma moves to the \\ key."),
        ],
        legendShift: "Shift",
        legendOptionShift: "Option+Shift",
        legendKey: "Key",
        legendOption: "Option",
        legendUzbekLetter: "Uzbek letter",
        legendChanged: "Types something different from a US keyboard",
        legendOptionKey: "Option (⌥) works like AltGr on Windows",
        otherOptionCharacters: "Other Option characters (– — … € and so on) type as on the Mac's U.S. layout.",
        badge: "Installed",
        installButton: { "Install \($0)" },
        installedButton: "Installed",
        removeButton: { "Remove \($0)" },
        afterInstallHint: "Switch between installed keyboards with 🌐 or Control + Space.",
        installedNow: { "\($0) is installed and turned on. Switch to it with the UZ icon in the menu bar, 🌐 or Control + Space." },
        removed: { "\($0) was removed." },
        removeInSettings: { "In the System Settings window that opened, under Text Input click Edit… next to Input Sources, select \($0) and click −. Then come back to this window." },
        failed: { "That didn't work: \($0)" },
        missingFiles: "The keyboard files inside this app are missing. Download the app again."
    )

    static let all = [uzbek, english]

    let languageName: String
    let windowTitle: String
    let heading: String
    let intro: String
    /// Card title and summary for each layout, by its name in macOS.
    let layouts: [String: (title: String, summary: String)]
    let legendShift: String
    let legendOptionShift: String
    let legendKey: String
    let legendOption: String
    let legendUzbekLetter: String
    let legendChanged: String
    let legendOptionKey: String
    let otherOptionCharacters: String
    let badge: String
    let installButton: (String) -> String
    let installedButton: String
    let removeButton: (String) -> String
    let afterInstallHint: String
    let installedNow: (String) -> String
    let removed: (String) -> String
    let removeInSettings: (String) -> String
    let failed: (String) -> String
    let missingFiles: String

    func title(_ layout: String) -> String { layouts[layout]?.title ?? layout }
    func summary(_ layout: String) -> String { layouts[layout]?.summary ?? "" }
}
