unit ExternalApps;


uses System;
uses System.IO;
uses System.Collections.Generic;
uses System.Text.RegularExpressions;


type
  ExternalAppPaths = class
    private _AppPaths: Dictionary<string, string>;
    
    public constructor (path: string);
    begin
      _AppPaths := new Dictionary<string, string>();
      
      if &File.Exists(path) then
        begin
          var exp   := new Regex('^\w+\s*=\s*[A-Za-z]:(\\[\w\-+.]+)+\s*$');
          var lines := &File.ReadAllLines(path);
          
          for var i := 0 to lines.Length-1 do
            begin
              var line := lines[i];
              
              var comment := line.IndexOf('#');
              if comment <> -1 then
                line := line.Substring(0, comment);
              
              line := Regex.Replace(line, '\s', '');
              
              if exp.IsMatch(line) then
                begin
                  var equ  := line.IndexOf('=');
                  _AppPaths.Add(line.Substring(0, equ), line.Substring(equ+1));
                end;
            end;
        end;
    end;
    
    public property AppPath[app: string]: string read (_AppPaths.ContainsKey(app) ? _AppPaths[app] : String.Empty);
  end;


end.