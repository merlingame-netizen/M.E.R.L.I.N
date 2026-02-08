Set WshShell = CreateObject("WScript.Shell")
' Attendre 2 secondes
WScript.Sleep 2000
' Ouvrir Command Palette (Ctrl+Shift+P)
WshShell.SendKeys "^+p"
WScript.Sleep 800
' Taper la commande
WshShell.SendKeys "Claude Code Open New Tab"
WScript.Sleep 1000
' Appuyer sur Entree
WshShell.SendKeys "{ENTER}"
WScript.Sleep 3000
' Coller le clipboard (Ctrl+V)
WshShell.SendKeys "^v"
