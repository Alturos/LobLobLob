7z a ..\builds\lob.zip @web-build.txt
butler push ..\builds\lob.zip --if-changed BrightMothGames/Lob-Lob-Lob:html 

pause