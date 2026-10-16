using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;

namespace UzbekKeyboardSetup;

sealed class KeyboardLayout
{
    static readonly string[] None = new string[4];

    public KeyboardLayout(string kbd, string productName, string klcFile)
    {
        Kbd = kbd;
        ProductName = productName;
        Keys = KlcParser.Load(klcFile);
    }

    /// <summary>MSKLC keyboard name; also the package folder and DLL name. Card text is looked up by it in <see cref="Strings"/>.</summary>
    public string Kbd { get; }

    /// <summary>Name Windows shows in Settings and in Installed apps (the KBD description in the .klc).</summary>
    public string ProductName { get; }

    /// <summary>Physical key code to the characters typed [alone, Shift, AltGr, AltGr+Shift]; null where nothing is typed.</summary>
    public IReadOnlyDictionary<string, string[]> Keys { get; }

    public string[] Get(string code) => Keys.TryGetValue(code, out var chars) ? chars : None;
}

static class Catalog
{
    public static readonly KeyboardLayout[] All =
    {
        new("uzlat26", "Uzbek Latin 2026 (Classic)", "Uzbek-Latin-2026-Classic.klc"),
        new("uzlt26d", "Uzbek Latin 2026 (Direct)", "Uzbek-Latin-2026-Direct.klc"),
        new("uzlt26t", "Uzbek Latin 2026 (Turkish-style)", "Uzbek-Latin-2026-Turkish-style.klc"),
    };

    /// <summary>The Classic layout keeps every unshifted and shifted US key in place.</summary>
    public static KeyboardLayout Us => All[0];
}

static class KlcParser
{
    // Scan code -> browser-style key code for the 47 main typing keys.
    static readonly Dictionary<string, string> ScanCodes = new(StringComparer.OrdinalIgnoreCase)
    {
        ["29"] = "Backquote", ["02"] = "Digit1", ["03"] = "Digit2", ["04"] = "Digit3", ["05"] = "Digit4",
        ["06"] = "Digit5", ["07"] = "Digit6", ["08"] = "Digit7", ["09"] = "Digit8", ["0a"] = "Digit9",
        ["0b"] = "Digit0", ["0c"] = "Minus", ["0d"] = "Equal",
        ["10"] = "KeyQ", ["11"] = "KeyW", ["12"] = "KeyE", ["13"] = "KeyR", ["14"] = "KeyT", ["15"] = "KeyY",
        ["16"] = "KeyU", ["17"] = "KeyI", ["18"] = "KeyO", ["19"] = "KeyP", ["1a"] = "BracketLeft",
        ["1b"] = "BracketRight", ["2b"] = "Backslash",
        ["1e"] = "KeyA", ["1f"] = "KeyS", ["20"] = "KeyD", ["21"] = "KeyF", ["22"] = "KeyG", ["23"] = "KeyH",
        ["24"] = "KeyJ", ["25"] = "KeyK", ["26"] = "KeyL", ["27"] = "Semicolon", ["28"] = "Quote",
        ["2c"] = "KeyZ", ["2d"] = "KeyX", ["2e"] = "KeyC", ["2f"] = "KeyV", ["30"] = "KeyB", ["31"] = "KeyN",
        ["32"] = "KeyM", ["33"] = "Comma", ["34"] = "Period", ["35"] = "Slash",
    };

    public static IReadOnlyDictionary<string, string[]> Load(string klcFile)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("klc/" + klcFile)
            ?? throw new InvalidOperationException(klcFile + " is not embedded in the setup.");
        using var reader = new StreamReader(stream, Encoding.Unicode, detectEncodingFromByteOrderMarks: true);

        var keys = new Dictionary<string, string[]>();
        var shiftStates = new List<int>();
        string section = null;
        string line;
        while ((line = reader.ReadLine()) != null)
        {
            var text = line.Split(new[] { "//" }, 2, StringSplitOptions.None)[0].Trim();
            if (text.Length == 0 || text.StartsWith(";"))
                continue;
            var parts = text.Split((char[])null, StringSplitOptions.RemoveEmptyEntries);
            if (IsKeyword(parts[0]))
            {
                section = parts[0];
                continue;
            }
            if (section == "SHIFTSTATE")
            {
                shiftStates.Add(int.Parse(parts[0], CultureInfo.InvariantCulture));
                continue;
            }
            if (section != "LAYOUT" || parts.Length < 3 + shiftStates.Count || !ScanCodes.TryGetValue(parts[0], out var code))
                continue;

            var chars = new string[4];
            for (int i = 0; i < shiftStates.Count; i++)
            {
                int slot = shiftStates[i] switch { 0 => 0, 1 => 1, 6 => 2, 7 => 3, _ => -1 };
                if (slot >= 0)
                    chars[slot] = Decode(parts[3 + i]);
            }
            keys[code] = chars;
        }
        return keys;
    }

    static bool IsKeyword(string token) => token.All(c => (c >= 'A' && c <= 'Z') || c == '_');

    static string Decode(string value)
    {
        if (value == "-1" || value == "%%")
            return null;
        if (value.Length == 1)
            return value;
        return int.TryParse(value.TrimEnd('@'), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var codePoint)
            ? char.ConvertFromUtf32(codePoint)
            : null;
    }
}
