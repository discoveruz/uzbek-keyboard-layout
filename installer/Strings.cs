using System;
using System.Collections.Generic;

namespace UzbekKeyboardSetup;

/// <summary>Every piece of text the window shows, in one language.</summary>
sealed class Strings
{
    // Uzbek text uses today's standard Latin spelling (oʻ, gʻ with U+02BB), which every reader knows.
    public static readonly Strings Uzbek = new()
    {
        LanguageName = "Oʻzbekcha",
        WindowTitle = "Oʻzbek lotin 2026 klaviaturasini oʻrnatish",
        Heading = "Klaviaturani tanlang",
        Intro = "Uchala klaviatura ham 2026-yilgi oʻzbek lotin alifbosidagi ö, ş, ğ, ç harflarini va ʼ belgisini yozadi. "
              + "Farqi faqat shu harflar qaysi tugmalarda turganida. Oʻzingizga yoqqanini tanlang. Keyinroq boshqasini ham oʻrnatishingiz mumkin.",
        Layouts = new Dictionary<string, (string, string)>
        {
            ["uzlat26"] = ("Klassik", "Barcha tugmalar US klaviaturadagi joyida qoladi. ö ş ğ ç harflari AltGr + O, S, G, C bilan yoziladi."),
            ["uzlt26d"] = ("Toʻgʻridan-toʻgʻri", "ö ş ğ harflari [ ; ' tugmalarida, ç esa C tugmasida. Oddiy c harfi AltGr + C bilan yoziladi."),
            ["uzlt26t"] = ("Turkcha uslub", "ö ş ğ harflari [ ; ' tugmalarida, ç esa vergul tugmasida. Vergul \\ tugmasiga koʻchadi."),
        },
        LegendShift = "Shift",
        LegendAltGrShift = "AltGr+Shift",
        LegendKey = "Tugma",
        LegendAltGr = "AltGr",
        LegendUzbekLetter = "Oʻzbek harfi",
        LegendChanged = "US klaviaturadan farq qiladi",
        LegendAltGrKey = "AltGr — oʻngdagi Alt tugmasi yoki Ctrl + Alt",
        Badge = "Oʻrnatilgan",
        InstallButton = _ => "Oʻrnatish",
        InstalledButton = "Oʻrnatilgan",
        RemoveLink = _ => "Oʻchirish",
        AfterInstallHint = "Oʻrnatgandan keyin klaviaturalar orasida Win + Space bilan almashasiz.",
        IsInstalled = product => $"{product} oʻrnatilgan. Unga oʻtish uchun Win + Space tugmalarini bosing.",
        NotIncluded = title => $"Bu oʻrnatish faylida «{title}» yoʻq.",
        ArmUnsupported = "Bu kompyuterda ARM protsessor bor. MSKLC bilan yaratilgan klaviaturalar faqat Intel va AMD kompyuterlarga oʻrnatiladi.",
        Installing = title => $"«{title}» oʻrnatilmoqda. Windows ruxsat soʻrasa, «Ha» (Yes) ni bosing.",
        InstalledNow = product => $"{product} oʻrnatildi. Unga oʻtish uchun Win + Space tugmalarini bosing. Roʻyxatda boʻlmasa, tizimdan chiqib, qayta kiring.",
        InstalledRestart = product => $"{product} oʻrnatildi. Tugatish uchun kompyuterni qayta ishga tushiring.",
        InstallCancelled = "Oʻrnatish bekor qilindi. Hech narsa oʻzgarmadi.",
        Removing = title => $"«{title}» oʻchirilmoqda. Windows ruxsat soʻrasa, «Ha» (Yes) ni bosing.",
        Removed = product => $"{product} oʻchirildi.",
        RemoveCancelled = "Oʻchirish bekor qilindi. Hech narsa oʻzgarmadi.",
        AnotherInstall = "Boshqa dastur oʻrnatilmoqda. U tugashini kuting va qayta urinib koʻring.",
        InstallerError = (code, log) => $"Windows Installer {code} xatosi bilan toʻxtadi. Tafsilotlar: {log}",
        CouldNotRun = message => $"Windows Installer ishga tushmadi: {message}",
    };

    public static readonly Strings English = new()
    {
        LanguageName = "English",
        WindowTitle = "Uzbek Latin 2026 Keyboard Setup",
        Heading = "Choose your keyboard",
        Intro = "All three keyboards type the Uzbek Latin 2026 letters ö, ş, ğ, ç and the ʼ sign. "
              + "They differ only in which keys those letters are on. Pick the one you like. You can install another one later.",
        Layouts = new Dictionary<string, (string, string)>
        {
            ["uzlat26"] = ("Classic", "Every key stays where it is on a US keyboard. Type ö ş ğ ç with AltGr + O, S, G, C."),
            ["uzlt26d"] = ("Direct", "ö ş ğ on the [ ; ' keys and ç on the C key. Plain c is AltGr + C."),
            ["uzlt26t"] = ("Turkish-style", "ö ş ğ on the [ ; ' keys and ç on the comma key. Comma moves to the \\ key."),
        },
        LegendShift = "Shift",
        LegendAltGrShift = "AltGr+Shift",
        LegendKey = "Key",
        LegendAltGr = "AltGr",
        LegendUzbekLetter = "Uzbek letter",
        LegendChanged = "Types something different from a US keyboard",
        LegendAltGrKey = "AltGr is the right Alt key, or Ctrl + Alt",
        Badge = "Installed",
        InstallButton = title => $"Install {title}",
        InstalledButton = "Installed",
        RemoveLink = title => $"Remove {title}",
        AfterInstallHint = "After installing, press Win + Space to switch between keyboards.",
        IsInstalled = product => $"{product} is installed. Press Win + Space to switch to it.",
        NotIncluded = title => $"{title} is not included in this setup file.",
        ArmUnsupported = "This PC has an ARM processor. Keyboards made with MSKLC only install on Intel and AMD PCs.",
        Installing = title => $"Installing {title}. If Windows asks for permission, choose Yes.",
        InstalledNow = product => $"{product} is installed. Press Win + Space to switch to it. If it isn't listed yet, sign out and back in.",
        InstalledRestart = product => $"{product} is installed. Restart Windows to finish.",
        InstallCancelled = "Installation cancelled. Nothing was changed.",
        Removing = title => $"Removing {title}. If Windows asks for permission, choose Yes.",
        Removed = product => $"{product} was removed.",
        RemoveCancelled = "Removal cancelled. Nothing was changed.",
        AnotherInstall = "Another installation is running. Wait for it to finish, then try again.",
        InstallerError = (code, log) => $"Windows Installer stopped with error {code}. Details: {log}",
        CouldNotRun = message => $"Couldn't run Windows Installer: {message}",
    };

    public static readonly Strings[] All = { Uzbek, English };

    public string LanguageName { get; set; }
    public string WindowTitle { get; set; }
    public string Heading { get; set; }
    public string Intro { get; set; }

    /// <summary>Card title and summary for each layout, keyed by its MSKLC keyboard name.</summary>
    public Dictionary<string, (string Title, string Summary)> Layouts { get; set; }

    public string LegendShift { get; set; }
    public string LegendAltGrShift { get; set; }
    public string LegendKey { get; set; }
    public string LegendAltGr { get; set; }
    public string LegendUzbekLetter { get; set; }
    public string LegendChanged { get; set; }
    public string LegendAltGrKey { get; set; }

    public string Badge { get; set; }
    public Func<string, string> InstallButton { get; set; }
    public string InstalledButton { get; set; }
    public Func<string, string> RemoveLink { get; set; }

    public string AfterInstallHint { get; set; }
    public Func<string, string> IsInstalled { get; set; }
    public Func<string, string> NotIncluded { get; set; }
    public string ArmUnsupported { get; set; }
    public Func<string, string> Installing { get; set; }
    public Func<string, string> InstalledNow { get; set; }
    public Func<string, string> InstalledRestart { get; set; }
    public string InstallCancelled { get; set; }
    public Func<string, string> Removing { get; set; }
    public Func<string, string> Removed { get; set; }
    public string RemoveCancelled { get; set; }
    public string AnotherInstall { get; set; }
    public Func<int, string, string> InstallerError { get; set; }
    public Func<string, string> CouldNotRun { get; set; }

    public string Title(KeyboardLayout layout) => Layouts[layout.Kbd].Title;
    public string Summary(KeyboardLayout layout) => Layouts[layout.Kbd].Summary;
}
