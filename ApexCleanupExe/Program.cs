using System.Diagnostics;
using System.Security.Principal;

static bool IsAdmin()
{
    using var identity = WindowsIdentity.GetCurrent();
    var principal = new WindowsPrincipal(identity);
    return principal.IsInRole(WindowsBuiltInRole.Administrator);
}

static void Step(string message)
{
    Console.WriteLine();
    Console.ForegroundColor = ConsoleColor.Cyan;
    Console.WriteLine("==> " + message);
    Console.ResetColor();
}

static string[] GetClientPaths(params string[] names)
{
    var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (var name in names)
    {
        foreach (var process in Process.GetProcessesByName(name))
        {
            using (process)
            {
                try
                {
                    var path = process.MainModule?.FileName;
                    if (!string.IsNullOrWhiteSpace(path))
                        paths.Add(path);
                }
                catch { }
            }
        }
    }
    return paths.ToArray();
}

static void Run(string fileName, string arguments)
{
    try
    {
        using var process = Process.Start(new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            UseShellExecute = false
        });
        process?.WaitForExit();
    }
    catch (Exception ex)
    {
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine($"{fileName} failed: {ex.Message}");
        Console.ResetColor();
    }
}

static bool ProcessExists(int id)
{
    try
    {
        using var process = Process.GetProcessById(id);
        return true;
    }
    catch
    {
        return false;
    }
}

static void StopByName(string label, params string[] names)
{
    Step("Closing " + label);
    foreach (var name in names)
    {
        foreach (var process in Process.GetProcessesByName(name))
        {
            var id = process.Id;
            using (process)
            {
                Console.WriteLine($"Stopping {process.ProcessName} pid={id}");
                try
                {
                    process.Kill(entireProcessTree: true);
                    process.WaitForExit(1000);
                }
                catch (Exception ex)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine($"Process kill failed for pid={id}: {ex.Message}");
                    Console.ResetColor();
                }
            }

            if (ProcessExists(id))
            {
                Console.WriteLine($"Process pid={id} is still visible; trying taskkill.");
                Run("taskkill.exe", $"/PID {id} /T /F");
            }
        }
    }
}

static string Quote(string value) => "\"" + value.Replace("\"", "\\\"") + "\"";

static void StopServices()
{
    Step("Stopping anti-cheat services if they are still running");
    var command = "Get-Service | Where-Object { $_.Name -like '*EasyAntiCheat*' -or $_.DisplayName -like '*Easy Anti-Cheat*' -or $_.Name -like '*EAAntiCheat*' -or $_.DisplayName -like '*EA Anti*' } | ForEach-Object { Write-Host \"$($_.DisplayName) [$($_.Name)] is $($_.Status)\"; if ($_.Status -eq 'Running') { Stop-Service -Name $_.Name -Force } }";
    Run("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -Command " + Quote(command));
}

static void StartClients(string label, IEnumerable<string> paths)
{
    var unique = paths.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
    if (unique.Length == 0)
        return;

    Step("Restarting " + label);
    foreach (var path in unique)
    {
        if (!File.Exists(path))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Skipped missing client path: " + path);
            Console.ResetColor();
            continue;
        }

        Console.WriteLine("Starting " + path);
        try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"Could not start {path}: {ex.Message}");
            Console.ResetColor();
        }
    }
}

static Process[] GetLeftovers()
{
    var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "r5apex", "r5apex_dx12", "EasyAntiCheat", "EasyAntiCheat_EOS", "EAAntiCheat",
        "EACefSubProcess", "EADesktop", "steam", "steamwebhelper", "GameOverlayUI"
    };
    return Process.GetProcesses().Where(p => names.Contains(p.ProcessName)).ToArray();
}

var restartIfStuck = args.Any(arg => string.Equals(arg, "--restart-if-stuck", StringComparison.OrdinalIgnoreCase));

if (!IsAdmin())
{
    Console.WriteLine("Please run ApexCleanup.exe as Administrator.");
    return 1;
}

Console.WriteLine("Apex cleanup tool");
Console.WriteLine("This only closes stuck game, EA App, Steam, and anti-cheat leftovers. It does not bypass anti-cheat.");

var eaClientPaths = GetClientPaths("EADesktop", "EALauncher");
var steamClientPaths = GetClientPaths("steam");

StopByName("Apex", "r5apex", "r5apex_dx12");
Thread.Sleep(1000);
StopByName("EA App leftovers", "EADesktop", "EALauncher", "EABackgroundService", "EACefSubProcess");
Thread.Sleep(1000);
StopByName("Steam leftovers", "steam", "steamwebhelper", "GameOverlayUI");
Thread.Sleep(1000);
StopByName("anti-cheat process leftovers", "EasyAntiCheat", "EasyAntiCheat_EOS", "EAAntiCheat.GameServiceLauncher", "EAAntiCheat.Installer");
StopServices();

StartClients("Steam", steamClientPaths);
StartClients("EA App", eaClientPaths);

Step("Final check");
var leftovers = GetLeftovers();
if (leftovers.Length == 0)
{
    Console.ForegroundColor = ConsoleColor.Green;
    Console.WriteLine("Done. Apex / EA / Steam / anti-cheat leftovers are closed.");
    Console.ResetColor();
    return 0;
}

foreach (var process in leftovers)
{
    using (process)
        Console.WriteLine($"{process.Id}\t{process.ProcessName}");
}

Console.ForegroundColor = ConsoleColor.Yellow;
Console.WriteLine();
Console.WriteLine("Some entries are still visible. If taskkill says there is no running instance, Windows is holding a dead process object.");
Console.WriteLine("That state is normally cleared by a reboot.");
Console.ResetColor();

if (restartIfStuck)
{
    Console.WriteLine("Restarting in 15 seconds. Press Ctrl+C to cancel.");
    Run("shutdown.exe", "/r /t 15 /c \"Restarting to clear stuck Apex / anti-cheat process\"");
}
else
{
    Console.WriteLine("Run ApexCleanup.exe --restart-if-stuck to reboot automatically if leftovers remain.");
}

Console.WriteLine("Press any key to close.");
Console.ReadKey(intercept: true);
return 2;
