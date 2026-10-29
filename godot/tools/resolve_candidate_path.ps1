param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$LiteralPath
)

# Resolve a Windows path through symlinks and junctions using the file handle.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not ("CandidatePathNative" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

public static class CandidatePathNative {
    private const uint FileShareAll = 0x00000007;
    private const uint OpenExisting = 3;
    private const uint BackupSemantics = 0x02000000;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(
        string fileName,
        uint desiredAccess,
        uint shareMode,
        IntPtr securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile
    );

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandleW(
        SafeFileHandle file,
        StringBuilder path,
        uint pathLength,
        uint flags
    );

    public static string Resolve(string path) {
        using (SafeFileHandle handle = CreateFileW(
                path,
                0,
                FileShareAll,
                IntPtr.Zero,
                OpenExisting,
                BackupSemantics,
                IntPtr.Zero)) {
            if (handle.IsInvalid) {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            uint capacity = 512;
            while (capacity <= 32768) {
                var buffer = new StringBuilder((int)capacity);
                uint length = GetFinalPathNameByHandleW(handle, buffer, capacity, 0);
                if (length == 0) {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }
                if (length < capacity) {
                    return buffer.ToString();
                }
                capacity *= 2;
            }
            throw new PathTooLongException("The resolved path exceeds the supported length.");
        }
    }
}
"@
}

$fullPath = [IO.Path]::GetFullPath($LiteralPath)
$existingPath = $fullPath
$missingParts = [Collections.Generic.List[string]]::new()

while (-not [IO.File]::Exists($existingPath) -and
        -not [IO.Directory]::Exists($existingPath)) {
    $leaf = [IO.Path]::GetFileName($existingPath)
    $parent = [IO.Path]::GetDirectoryName($existingPath)
    if ([string]::IsNullOrEmpty($leaf) -or
            [string]::IsNullOrEmpty($parent) -or
            $parent -eq $existingPath) {
        throw "No existing ancestor could be resolved for: $fullPath"
    }
    $missingParts.Insert(0, $leaf)
    $existingPath = $parent
}

$canonicalPath = [CandidatePathNative]::Resolve($existingPath)
if ($canonicalPath.StartsWith("\\?\UNC\", [StringComparison]::OrdinalIgnoreCase)) {
    $canonicalPath = "\\" + $canonicalPath.Substring(8)
} elseif ($canonicalPath.StartsWith("\\?\",
        [StringComparison]::OrdinalIgnoreCase)) {
    $canonicalPath = $canonicalPath.Substring(4)
}

foreach ($part in $missingParts) {
    $canonicalPath = [IO.Path]::Combine($canonicalPath, $part)
}

$root = [IO.Path]::GetPathRoot($canonicalPath)
if ($canonicalPath.Length -gt $root.Length) {
    $canonicalPath = $canonicalPath.TrimEnd('\', '/')
}

Write-Output $canonicalPath
