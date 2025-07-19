{$apptype windows}

{$reference System.Windows.Forms.dll}

{$mainresource res\res.res}


uses System;
uses System.Globalization;
uses System.Windows.Forms;
uses FileTreeMainForm;


begin
  Application.EnableVisualStyles();
  Application.SetCompatibleTextRenderingDefault(false);
  Application.Run(new MainForm());
end.