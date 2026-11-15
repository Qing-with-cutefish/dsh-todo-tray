' ============================================================
'  dsh-todo-tray 0.2.0 - launcher (R1: no console window)
'  wscript.exe is a GUI host, so no console/terminal window appears
'  on the desktop. Do NOT replace this with
'      start "" powershell.exe ... -WindowStyle Hidden
'  on Windows 11 that console is delegated to Windows Terminal and the
'  black window stays (evidence: internal test notes).
'  This file must stay ASCII (wscript reads it as ANSI).
' ============================================================
Option Explicit

Dim fso, sh, dir, ps1, exe, cmd, extra, i

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

dir = fso.GetParentFolderName(WScript.ScriptFullName)
' repo layout: todo-tray.ps1 lives in ..\src
ps1 = fso.BuildPath(fso.BuildPath(dir, "..\src"), "todo-tray.ps1")
If Not fso.FileExists(ps1) Then
    MsgBox "todo-tray.ps1 not found:" & vbCrLf & ps1, 16, "dsh-todo-tray"
    WScript.Quit 2
End If

exe = fso.BuildPath(sh.ExpandEnvironmentStrings("%SystemRoot%"), "System32\WindowsPowerShell\v1.0\powershell.exe")

extra = ""
For i = 0 To WScript.Arguments.Count - 1
    extra = extra & " " & Quote(WScript.Arguments(i))
Next

cmd = Quote(exe) & " -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Quote(ps1) & extra
' 0 = hidden window, False = do not wait for it to exit
sh.Run cmd, 0, False

Function Quote(s)
    Quote = Chr(34) & s & Chr(34)
End Function
