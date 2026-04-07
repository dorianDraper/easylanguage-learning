{-------------------------------------------------------------------
    Password Protection v1

    Description:
    - This indicator demonstrates how to implement password protection in EasyLanguage.
    - The user must enter the correct password to access the indicator's functionality.

    Implements three levels of password protection:
        1) Environment validation (symbol / bar type)
        2) Password-based license
        3) License expiration window
-------------------------------------------------------------------}

Input:
	// User debe introducir password
	Password("A123456789");

Vars:
	// El entorno es válido
	OK(False);

// Con Once el código se ejecuta solo una vez durante la inicialización del indicador
Once Begin
	If {Getscreenname = "LOGINID" and} //Optional username
		GetSymbolName = "MSFT" and Bartype = 2 Then
			OK = True;
End;

If OK and 
((Date < 1200601 and Password = "A123456789") or 
(Date > 1200401 and Password = "B123456789"))
Then
Begin
	Plot1(Average(Close, 20), "MA");
End;	