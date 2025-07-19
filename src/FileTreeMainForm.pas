unit FileTreeMainForm;


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


uses System;
uses System.IO;
uses System.Threading;
uses System.Threading.Tasks;
uses System.Diagnostics;
uses System.Drawing;
uses System.Windows.Forms;
uses Extensions;
uses FileIcon;
uses ExternalApps;


type
  MainForm = class(Form)
    {$region Fields}
    private _PathView     : TreeView;
    private _ImageList    : ImageList;
    private _FileMenu     : System.Windows.Forms.ContextMenuStrip;
    private _FolderMenu   : System.Windows.Forms.ContextMenuStrip;
    private _ExternalApps : ExternalAppPaths;
    private _ExpandEnd    : boolean;
    {$endregion}
    
    {$region Routines}
    private function GetIconKeyFromExt(fname: string): string;
    begin
      var p := fname.LastIndexOf('.');
      
      if p = -1 then
        result := 'file'
      else
        begin
          var ext := fname.Substring(p+1);
          
          if ext = 'exe' then
            ext := fname;
    
          if not _ImageList.Images.ContainsKey(ext) then
            _ImageList.Images.Add(ext, GetFileIcon(fname));
              
          result := ext;
        end;
    end;
    
    private function GetColorFromAttribute(fname: string; dir: boolean := false): Color;
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
    
    private function CreateNode(root: TreeNode; path: string; folder: boolean := true): TreeNode;
    begin
      var node := new TreeNode(path.Substring(path.LastIndexOf('\') + 1));
      var key  := folder ? 'folder' : GetIconKeyFromExt(path);
      
      node.ImageKey         := key;
      node.SelectedImageKey := key;
      node.ForeColor        := GetColorFromAttribute(path, true);
      node.ContextMenuStrip := folder ? _FolderMenu : _FileMenu;
      
      Invoke(() -> root.Nodes.Add(node));
      
      result := node;
    end;
    
    private procedure FillTreeNode(node: TreeNode; path: string; dept: integer := 1);
    begin
      Invoke(() -> node.Nodes.Clear());
      
      if path[path.Length] = ':' then
        path += '\';
      
      var ErrorMessage: string;
      try
        if dept = 1 then
          begin
            foreach var f: string in Directory.GetDirectories(path) do
              begin
                var folder := CreateNode(node, f);
                
                if dept > 0 then
                  FillTreeNode(folder, f, dept-1);
              end;
            
            foreach var f: string in Directory.GetFiles(path) do
              CreateNode(node, f, false);
          end
        else
          begin
            var folders := Directory.GetDirectories(path);
            var files   := Directory.GetFiles(path);
            
            if folders.Length > 0 then
              CreateNode(node, folders[0])
            else if files.Length > 0 then
              CreateNode(node, files[0], false);
          end;
      except on ex: Exception do
        begin
          ErrorMessage := ex.Message;
          Invoke(() -> 
            begin
              node.ForeColor   := Color.Gray;
              node.ToolTipText := ErrorMessage;
            end
          );
        end;
      end;
      
      if dept = 1 then
        begin
          Invoke(() -> begin Cursor := Cursors.Default; end);
          _ExpandEnd := true;
        end;
    end;
    
    private function FindNode(node: TreeNode; name: string): TreeNode;
    begin
      result := nil;
      
      var nodes := node <> nil ? node.Nodes : _PathView.Nodes;
      
      foreach var n: TreeNode in nodes do
        if n.Text.ToLower() = name then
          begin
            result := n;
            break;
          end;
    end;
    
    private procedure OpenPath(path: string);
    begin
      try
        var node: TreeNode := nil;
        var parents := path.ToLower().Split('\');
        
        foreach var parent in parents do
          begin
            Invoke(() -> begin node := FindNode(node, parent); end);
            
            if node <> nil then
              begin
                _ExpandEnd := false;
                
                Invoke(() -> 
                  begin
                    node.Expand();
                    _ExpandEnd := node.Nodes.Count = 0;
                  end
                );
                
                repeat
                  Thread.Sleep(10);
                until _ExpandEnd;
              end
            else
              break;
          end;
          
          Invoke(() ->
            begin
              if node <> nil then
                _PathView.SelectedNode := node; 
            end
          );
      except on ex: Exception do
        Message.Error(ex.Message);
      end;
    end;
    
    private procedure WinRun(app: string; args: string := ''; parent: boolean := false);
    begin
      var path := _PathView.SelectedNode.FullPath;
      
      if parent then
        path := path.Substring(0, path.LastIndexOf('\'));
      
      args += $' "{path}"';
      
      try
        Process.Start(app, args);
      except on ex: Exception do
        Message.Error($'Execute {app} {args} error: {ex.Message}');
      end;
    end;
    {$endregion}
    
    {$region Handlers}
    private procedure PathViewBeforeExpand(sender: object; e: TreeViewCancelEventArgs);
    begin
      Cursor := Cursors.WaitCursor;
      Task.Factory.StartNew(() -> FillTreeNode(e.Node, e.Node.FullPath));
    end;
    
    private procedure PathViewMouseClick(sender: object; e: MouseEventArgs);
    begin
      if e.Button = System.Windows.Forms.MouseButtons.Right then
        _PathView.SelectedNode := _PathView.GetNodeAt(e.Location);
    end;
    {$endregion}
    
    {$region Ctors}
    public constructor ();
    begin
      {$region MainForm}
      ClientSize    := new System.Drawing.Size(410, 520);
      MinimumSize   := Size;
      Icon          := Resources.Icon('icon.ico');
      StartPosition := FormStartPosition.CenterScreen;
      Text          := 'File Tree';
      {$endregion}
      
      {$region PathView}
      _ImageList            := new ImageList();
      _ImageList.ColorDepth := ColorDepth.Depth32Bit;
      _ImageList.ImageSize  := new System.Drawing.Size(16, 16);
      _ImageList.Images.Add('disk',   Resources.Image('disk.png'));
      _ImageList.Images.Add('folder', Resources.Image('folder.png'));
      _ImageList.Images.Add('file',   Resources.Image('file.png'));
      
      _PathView                  := new TreeView();
      _PathView.Size             := new System.Drawing.Size(400, 475);
      _PathView.Location         := new System.Drawing.Point(5, 5);
      _PathView.BorderStyle      := System.Windows.Forms.BorderStyle.None;
      _PathView.Dock             := DockStyle.Fill;
      _PathView.ImageList        := _ImageList;
      _PathView.ItemHeight       := 18;
      _PathView.ShowNodeToolTips := true;
      _PathView.ShowRootLines    := false;
      _PathView.ShowPlusMinus    := true;
      _PathView.Scrollable       := true;
      _PathView.BeforeExpand     += PathViewBeforeExpand;
      _PathView.MouseClick       += PathViewMouseClick;
      Controls.Add(_PathView);
      {$endregion}
      
      {$region NodeMenu}
      _FolderMenu := new System.Windows.Forms.ContextMenuStrip();
      
      var _OpenInExplorer   := new ToolStripMenuItem();
      _OpenInExplorer.Text  := 'Open in Explorer'; 
      _OpenInExplorer.Image := Resources.Image('path.png');
      _OpenInExplorer.Click += (sender, e) -> WinRun('explorer.exe');
      _FolderMenu.Items.Add(_OpenInExplorer);
      
      var _OpenTerminal   := new ToolStripMenuItem();
      _OpenTerminal.Text  := 'Open Terminal'; 
      _OpenTerminal.Image := Resources.Image('cmder.png');
      _OpenTerminal.Click += (sender, e) -> WinRun(_ExternalApps.AppPath['terminal'], '/start');
      _FolderMenu.Items.Add(_OpenTerminal);
      
      var CopyPath   := new ToolStripMenuItem();
      CopyPath.Text  := 'Copy Path'; 
      CopyPath.Image := Resources.Image('copy.png');
      CopyPath.Click += (sender, e) -> Clipboard.SetText(_PathView.SelectedNode.FullPath);
      _FolderMenu.Items.Add(CopyPath);
      
      _FileMenu := new System.Windows.Forms.ContextMenuStrip();
      
      var _OpenAsText   := new ToolStripMenuItem();
      _OpenAsText.Text  := 'Open with Notepad++'; 
      _OpenAsText.Image := Resources.Image('text.png');
      _OpenAsText.Click += (sender, e) -> WinRun(_ExternalApps.AppPath['notepad']);
      _FileMenu.Items.Add(_OpenAsText);
      
      var _OpenAsHex   := new ToolStripMenuItem();
      _OpenAsHex.Text  := 'Open with HexEditor'; 
      _OpenAsHex.Image := Resources.Image('hex.png');
      _OpenAsHex.Click += (sender, e) -> WinRun(_ExternalApps.AppPath['hexeditor']);
      _FileMenu.Items.Add(_OpenAsHex);
      
      var _OpenParent   := new ToolStripMenuItem();
      _OpenParent.Text  := 'Open parent folder'; 
      _OpenParent.Image := Resources.Image('path.png');
      _OpenParent.Click += (sender, e) -> WinRun('explorer.exe', '', true);
      _FileMenu.Items.Add(_OpenParent);
      
      var _CopyFilePath   := new ToolStripMenuItem();
      _CopyFilePath.Text  := 'Copy Path'; 
      _CopyFilePath.Image := Resources.Image('copy.png');
      _CopyFilePath.Click += (sender, e) -> Clipboard.SetText(_PathView.SelectedNode.FullPath);
      _FileMenu.Items.Add(_CopyFilePath);
      {$endregion}
      
      {$region Init}
      var path := Application.ExecutablePath;
      path := path.Substring(0, path.LastIndexOf('\') + 1) + 'path.h';
      _ExternalApps := new ExternalAppPaths(path);
      
      foreach var drive: DriveInfo in DriveInfo.GetDrives() do
        begin
          var disk              := new TreeNode();
          disk.Text             := drive.Name.TrimEnd('\');
          disk.ImageKey         := 'disk';
          disk.SelectedImageKey := 'disk';
            
          try
            foreach var directory in Directory.GetDirectories(disk.Text+'\') do
              begin
                var folder              := new TreeNode();
                folder.Text             := directory.Substring(directory.LastIndexOf('\') + 1);
                folder.ImageKey         := 'folder';
                folder.SelectedImageKey := 'folder';
                folder.ForeColor        := GetColorFromAttribute(directory, true);
                folder.ContextMenuStrip := _FolderMenu;
                disk.Nodes.Add(folder);
              end;
          except on ex: Exception do 
            begin
              disk.ForeColor   := Color.Gray;
              disk.ToolTipText := ex.Message; 
            end;
          end;
              
          _PathView.Nodes.Add(disk);
        end;
      
      var args := Environment.GetCommandLineArgs();
      if args.Length > 1 then
        begin
          path := args[1];
            
          if Directory.Exists(path) then
            Task.Factory.StartNew(() -> OpenPath(path))
          else
            Text += $' - "{path}" not found.';
        end;
      {$endregion}
    end;
    {$endregion}
  end;


end.