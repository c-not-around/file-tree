{$apptype windows}

{$reference System.Drawing.dll}
{$reference System.Windows.Forms.dll}

{$resource res\icon.ico}
{$resource res\disk.png}
{$resource res\folder.png}
{$resource res\file.png}
{$resource res\path.png}
{$resource res\cmder.png}
{$resource res\copy.png}
{$resource res\text.png}
{$resource res\hex.png}

{$mainresource res\res.res}


uses
  System,
  System.IO,
  System.Threading,
  System.Threading.Tasks,
  System.Diagnostics,
  System.Drawing,
  System.Windows.Forms,
  FileIcon;


var
  Main      : Form;
  PathView  : TreeView;
  ImgList   : ImageList;
  FileMenu  : ContextMenuStrip;
  FolderMenu: ContextMenuStrip;
  CmderPath : string;
  HexEditor : string;
  Notepad   : string;


{$region Utils}
function GetIconFromExt(fname: string): string;
begin
  var p := fname.LastIndexOf('.');
  
  if p = -1 then
    result := 'file'
  else
    begin
      var ext := fname.Substring(p+1);
      
      if ext = 'exe' then
        ext := fname;

      if not ImgList.Images.ContainsKey(ext) then
        ImgList.Images.Add(ext, GetFileIcon(fname));
          
      result := ext;
    end;
end;

function GetColorFromAttribute(fname: string; dir: boolean := false): Color;
begin
  var attributes := dir ? (new DirectoryInfo(fname)).Attributes : (new FileInfo(fname)).Attributes;
  
  if (attributes and FileAttributes.System) = FileAttributes.System then
    result := Color.Red
  else if (attributes and FileAttributes.Hidden) = FileAttributes.Hidden then
    result := Color.Blue
  else if (attributes and FileAttributes.Device) = FileAttributes.Device then
    result := Color.DarkMagenta
  else
    result := Color.Black;
end;

procedure FillTreeNode(node: TreeNode; path: string; dept: integer := 0);
begin
  if path[path.Length] = ':' then
    path += '\';
  
  try
    foreach var f: string in Directory.GetDirectories(path) do
      begin
        var folder              := new TreeNode();
        folder.Text             := f.Substring(f.LastIndexOf('\') + 1);
        folder.ImageKey         := 'folder';
        folder.SelectedImageKey := 'folder';
        folder.ForeColor        := GetColorFromAttribute(f, true);
        folder.ContextMenuStrip := FolderMenu;
        
        if dept > 0 then
          FillTreeNode(folder, f, dept-1);
        
        node.Nodes.Add(folder);
      end;
      
    foreach var f: string in Directory.GetFiles(path) do
      begin
        var &file              := new TreeNode();
        &file.Text             := f.Substring(f.LastIndexOf('\') + 1);
        var ImageKey           := GetIconFromExt(f);
        &file.ImageKey         := ImageKey;
        &file.SelectedImageKey := ImageKey;
        &file.ForeColor        := GetColorFromAttribute(f);
        &file.ContextMenuStrip := FileMenu;
        
        node.Nodes.Add(&file);
      end;
  except on ex: Exception do
    begin
      node.ForeColor   := Color.Gray;
      node.ToolTipText := ex.Message;
    end;
  end;
end;
{$endregion}

{$region Handlers}
procedure PathViewBeforeExpand(sender: object; e: TreeViewCancelEventArgs);
begin
  e.Node.Nodes.Clear();
  FillTreeNode(e.Node, e.Node.FullPath, 1);
end;

procedure PathViewMouseClick(sender: object; e: MouseEventArgs);
begin
  if e.Button = MouseButtons.Right then
    PathView.SelectedNode := PathView.GetNodeAt(e.Location);
end;

procedure OpenInExplorerClick(sender: object; e: EventArgs);
begin
  Process.Start(PathView.SelectedNode.FullPath);
end;

procedure OpenTerminalClick(sender: object; e: EventArgs);
begin
  try
    Process.Start(CmderPath, '/start "'+PathView.SelectedNode.FullPath+'"');
  except on ex: Exception do
    MessageBox.Show('Cmder.exe start error: '+ex.Message, 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
  end;
end;

procedure CopyPathClick(sender: object; e: EventArgs);
begin
  Clipboard.SetText(PathView.SelectedNode.FullPath);
end;

procedure OpenAsTextClick(sender: object; e: EventArgs);
begin
  try
    Process.Start(Notepad, '"'+PathView.SelectedNode.FullPath+'"');
  except on ex: Exception do
    MessageBox.Show('Notepad++.exe start error: '+ex.Message, 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
  end;
end;

procedure OpenAsHexClick(sender: object; e: EventArgs);
begin
  try
    Process.Start(HexEditor, '"'+PathView.SelectedNode.FullPath+'"');
  except on ex: Exception do
    MessageBox.Show('Be.HexEditor.exe start error: '+ex.Message, 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
  end;
end;

procedure OpenParentClick(sender: object; e: EventArgs);
begin
  var path := PathView.SelectedNode.FullPath;
  Process.Start(path.Substring(0, path.LastIndexOf('\')));
end;

procedure CopyFilePathClick(sender: object; e: EventArgs);
begin
  Clipboard.SetText(PathView.SelectedNode.FullPath);
end;
{$endregion}

begin
  {$region App}
  Application.EnableVisualStyles();
  Application.SetCompatibleTextRenderingDefault(false);
  {$endregion}
  
  {$region MainForm}
  Main                 := new Form();
  Main.ClientSize      := new Size(410, 520);
  Main.MinimumSize     := new Size(425, 555);
  Main.Icon            := new Icon(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('icon.ico'));
  Main.StartPosition   := FormStartPosition.CenterScreen;
  Main.Text            := 'File Tree';
  {$endregion}
  
  {$region PathView}
  ImgList            := new ImageList();
  ImgList.ColorDepth := ColorDepth.Depth32Bit;
  ImgList.ImageSize  := new Size(16,16);
  ImgList.Images.Add('disk', Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('disk.png')));
  ImgList.Images.Add('folder', Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('folder.png')));
  ImgList.Images.Add('file', Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('file.png')));
  
  PathView                  := new TreeView();
  PathView.Size             := new System.Drawing.Size(400, 475);
  PathView.Location         := new System.Drawing.Point(5, 5);
  PathView.Dock             := DockStyle.Fill;
  PathView.ImageList        := ImgList;
  PathView.ItemHeight       := 18;
  PathView.ShowNodeToolTips := true;
  PathView.ShowRootLines    := false;
  PathView.ShowPlusMinus    := true;
  PathView.Scrollable       := true;
  PathView.BeforeExpand     += PathViewBeforeExpand;
  PathView.MouseClick       += PathViewMouseClick;
  Main.Controls.Add(PathView);
  {$endregion}
  
  {$region NodeMenu}
  FolderMenu := new ContextMenuStrip();
  
  var OpenInExplorer   := new ToolStripMenuItem();
  OpenInExplorer.Text  := 'Open in Explorer'; 
  OpenInExplorer.Image := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('path.png'));
  OpenInExplorer.Click += OpenInExplorerClick;
  FolderMenu.Items.Add(OpenInExplorer);
  
  var OpenTerminal   := new ToolStripMenuItem();
  OpenTerminal.Text  := 'Open Terminal'; 
  OpenTerminal.Image := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('cmder.png'));
  OpenTerminal.Click += OpenTerminalClick;
  FolderMenu.Items.Add(OpenTerminal);
  
  var CopyPath   := new ToolStripMenuItem();
  CopyPath.Text  := 'Copy Path'; 
  CopyPath.Image := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('copy.png'));
  CopyPath.Click += CopyPathClick;
  FolderMenu.Items.Add(CopyPath);
  
  FileMenu := new ContextMenuStrip();
  
  var OpenAsText   := new ToolStripMenuItem();
  OpenAsText.Text  := 'Open with Notepad++'; 
  OpenAsText.Image := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('text.png'));
  OpenAsText.Click += OpenAsTextClick;
  FileMenu.Items.Add(OpenAsText);
  
  var OpenAsHex   := new ToolStripMenuItem();
  OpenAsHex.Text  := 'Open with HexEditor'; 
  OpenAsHex.Image := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('hex.png'));
  OpenAsHex.Click += OpenAsHexClick;
  FileMenu.Items.Add(OpenAsHex);
  
  var OpenParent   := new ToolStripMenuItem();
  OpenParent.Text  := 'Open parent folder'; 
  OpenParent.Image := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('path.png'));
  OpenParent.Click += OpenParentClick;
  FileMenu.Items.Add(OpenParent);
  
  var CopyFilePath   := new ToolStripMenuItem();
  CopyFilePath.Text  := 'Copy Path'; 
  CopyFilePath.Image := Image.FromStream(System.Reflection.Assembly.GetEntryAssembly().GetManifestResourceStream('copy.png'));
  CopyFilePath.Click += CopyFilePathClick;
  FileMenu.Items.Add(CopyFilePath);
  {$endregion}
  
  {$region Init}
  foreach var drive: DriveInfo in DriveInfo.GetDrives() do
    begin
      var disk              := new TreeNode();
      disk.Text             := drive.Name.TrimEnd('\');
      disk.ImageKey         := 'disk';
      disk.SelectedImageKey := 'disk';
        
      FillTreeNode(disk, disk.Text);
        
      PathView.Nodes.Add(disk);
    end;
  
  var path := Application.ExecutablePath;
  path := path.Substring(0, path.LastIndexOf('\')) + '\path.h';
  if &File.Exists(path) then
    foreach var line in &File.ReadAllLines(path) do
      if line <> '' then
        begin
          var kw := line.Split('=');
          if kw.Length = 2 then
            case kw[0].ToLower() of
              'terminal':  CmderPath := kw[1] + '\Cmder.exe';
              'hexeditor': HexEditor := kw[1] + '\Be.HexEditor.exe';
              'notepad':   Notepad   := kw[1] + '\notepad++.exe';
            end;
        end;
  {$endregion}
  
  {$region App}
  Application.Run(Main);
  {$endregion}
end.