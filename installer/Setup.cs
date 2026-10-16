using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace UzbekKeyboardSetup;

enum MachineKind { X64, X86, Arm64 }

sealed class MsiResult
{
    public MsiResult(int exitCode, string logPath)
    {
        ExitCode = exitCode;
        LogPath = logPath;
    }

    public int ExitCode { get; }
    public string LogPath { get; }
}

/// <summary>Installs and removes the MSKLC setup packages embedded in this program.</summary>
static class Setup
{
    public static MachineKind Machine { get; } = DetectMachine();

    public static bool HasPackage(KeyboardLayout layout) =>
        PackageResources(layout).Any(name => name.EndsWith(".msi", StringComparison.OrdinalIgnoreCase));

    /// <summary>The Windows Installer product code if this layout is installed, otherwise null.</summary>
    public static string FindInstalledProductCode(KeyboardLayout layout)
    {
        var places = new[]
        {
            (RegistryHive.LocalMachine, RegistryView.Registry64),
            (RegistryHive.LocalMachine, RegistryView.Registry32),
            (RegistryHive.CurrentUser, RegistryView.Default),
        };
        foreach (var (hive, view) in places)
        {
            using var root = RegistryKey.OpenBaseKey(hive, view);
            using var uninstall = root.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall");
            if (uninstall == null)
                continue;
            foreach (var name in uninstall.GetSubKeyNames())
            {
                using var app = uninstall.OpenSubKey(name);
                if (app?.GetValue("DisplayName") as string == layout.ProductName && IsProductCode(name))
                    return name;
            }
        }
        return null;
    }

    public static async Task<MsiResult> InstallAsync(KeyboardLayout layout)
    {
        string folder = await Task.Run(() => Extract(layout));
        string arch = Machine == MachineKind.X86 ? "i386" : "amd64";
        string msi = Path.Combine(folder, $"{layout.Kbd}_{arch}.msi");
        string log = Path.Combine(folder, "install.log");
        int exitCode = await RunMsiexecAsync($"/i \"{msi}\" /qb /norestart /l*v \"{log}\"");
        return new MsiResult(exitCode, log);
    }

    public static async Task<MsiResult> RemoveAsync(KeyboardLayout layout, string productCode)
    {
        if (!IsProductCode(productCode))
            throw new ArgumentException("Not a product code.", nameof(productCode));
        string folder = WorkFolder(layout);
        Directory.CreateDirectory(folder);
        string log = Path.Combine(folder, "remove.log");
        int exitCode = await RunMsiexecAsync($"/x {productCode} /qb /norestart /l*v \"{log}\"");
        return new MsiResult(exitCode, log);
    }

    static string WorkFolder(KeyboardLayout layout) => Path.Combine(Path.GetTempPath(), "UzbekKeyboardSetup", layout.Kbd);

    static string[] PackageResources(KeyboardLayout layout)
    {
        string prefix = "pkg/" + layout.Kbd + "\\";
        return Assembly.GetExecutingAssembly().GetManifestResourceNames()
            .Where(name => name.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            .ToArray();
    }

    /// <summary>Writes the MSKLC package (the .msi files and the amd64/i386/ia64/wow64 DLL folders it reads from) to a temp folder.</summary>
    static string Extract(KeyboardLayout layout)
    {
        string folder = WorkFolder(layout);
        if (Directory.Exists(folder))
            Directory.Delete(folder, recursive: true);
        string prefix = "pkg/" + layout.Kbd + "\\";
        var assembly = Assembly.GetExecutingAssembly();
        foreach (var name in PackageResources(layout))
        {
            string path = Path.Combine(folder, name.Substring(prefix.Length).Replace('/', '\\'));
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            using var source = assembly.GetManifestResourceStream(name);
            using var target = File.Create(path);
            source.CopyTo(target);
        }
        return folder;
    }

    static Task<int> RunMsiexecAsync(string arguments) => Task.Run(() =>
    {
        var info = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "msiexec.exe"), arguments) { UseShellExecute = false };
        using var process = Process.Start(info);
        process.WaitForExit();
        return process.ExitCode;
    });

    static bool IsProductCode(string value) =>
        value != null && value.Length == 38 && value[0] == '{' && Guid.TryParse(value, out _);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool IsWow64Process2(IntPtr process, out ushort processMachine, out ushort nativeMachine);

    static MachineKind DetectMachine()
    {
        try
        {
            if (IsWow64Process2(Process.GetCurrentProcess().Handle, out _, out ushort native))
                return native switch { 0xAA64 => MachineKind.Arm64, 0x014C => MachineKind.X86, _ => MachineKind.X64 };
        }
        catch (EntryPointNotFoundException)
        {
            // Windows 10 before 1709 has no IsWow64Process2.
        }
        return Environment.Is64BitOperatingSystem ? MachineKind.X64 : MachineKind.X86;
    }
}
