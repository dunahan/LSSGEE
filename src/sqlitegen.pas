unit sqlitegen;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, Spin;

type

  { TsqlitegenForm }

  TsqlitegenForm = class(TForm)
    ButtonSetValue: TButton;
    ButtonGetValue: TButton;
    ButtonClose: TButton;
    ComboScope: TComboBox;
    EditKey: TEdit;
    EditValue: TEdit;
    LabelScope: TLabel;
    LabelKey: TLabel;
    LabelValue: TLabel;
    LabelTitle: TLabel;
    MemoOutput: TMemo;
    LabelOutput: TLabel;
    PanelControls: TPanel;
    PanelOutput: TPanel;

    procedure FormCreate(Sender: TObject);
    procedure ButtonSetValueClick(Sender: TObject);
    procedure ButtonGetValueClick(Sender: TObject);
    procedure ButtonCloseClick(Sender: TObject);

  private
    QueuedLines: array of shortstring;
    procedure GenerateSetValue;
    procedure GenerateGetValue;
    procedure AddLineToQueue(const Line: shortstring);
    procedure OutputToScript;

  public
  end;

var
  sqlitegenForm: TsqlitegenForm;

implementation

uses
  start;

{$R *.lfm}

procedure TsqlitegenForm.FormCreate(Sender: TObject);
begin
  ComboScope.Items.Add('Module-level (persistent within module)');
  ComboScope.Items.Add('Campaign-level (persistent across area transitions)');
  ComboScope.ItemIndex := 0;

  SetLength(QueuedLines, 0);
  EditKey.Text := '';
  EditValue.Text := '';
  MemoOutput.Clear;
end;

procedure TsqlitegenForm.AddLineToQueue(const Line: shortstring);
var
  idx: integer;
begin
  idx := Length(QueuedLines);
  SetLength(QueuedLines, idx + 1);
  QueuedLines[idx] := Line;
end;

procedure TsqlitegenForm.GenerateSetValue;
var
  scope_prefix: shortstring;
  query_func: shortstring;
  key: shortstring;
  value: shortstring;
begin
  key := Trim(EditKey.Text);
  value := Trim(EditValue.Text);

  if key = '' then
  begin
    ShowMessage('Please enter a variable key name');
    Exit;
  end;

  if value = '' then
  begin
    ShowMessage('Please enter a value to store');
    Exit;
  end;

  SetLength(QueuedLines, 0);

  // Determine scope
  if ComboScope.ItemIndex = 0 then
  begin
    scope_prefix := 'Module';
    query_func := 'SqlPrepareQueryModule';
  end
  else
  begin
    scope_prefix := 'Campaign';
    query_func := 'SqlPrepareQueryCampaign';
  end;

  AddLineToQueue('// Set persistent ' + scope_prefix + '-level value');
  AddLineToQueue('sqlquery sql_query;');
  AddLineToQueue('sql_query = ' + query_func + '();');
  AddLineToQueue('');
  AddLineToQueue('// Execute: INSERT OR REPLACE INTO variables (key, value)');
  AddLineToQueue('SqlBindString(sql_query, 1, "' + key + '");');
  AddLineToQueue('SqlBindString(sql_query, 2, "' + value + '");');
  AddLineToQueue('');
  AddLineToQueue('if (SqlStep(sql_query) == SQL_FINISHED)');
  AddLineToQueue('  SqlDebug("Variable stored: ' + key + '");');
  AddLineToQueue('else');
  AddLineToQueue('  SqlDebug("ERROR storing variable");');

  OutputToScript;
end;

procedure TsqlitegenForm.GenerateGetValue;
var
  scope_prefix: shortstring;
  query_func: shortstring;
  key: shortstring;
  varname: shortstring;
begin
  key := Trim(EditKey.Text);

  if key = '' then
  begin
    ShowMessage('Please enter the variable key to retrieve');
    Exit;
  end;

  SetLength(QueuedLines, 0);

  // Determine scope
  if ComboScope.ItemIndex = 0 then
  begin
    scope_prefix := 'Module';
    query_func := 'SqlPrepareQueryModule';
  end
  else
  begin
    scope_prefix := 'Campaign';
    query_func := 'SqlPrepareQueryCampaign';
  end;

  varname := 'sResult_' + key;

  AddLineToQueue('// Get persistent ' + scope_prefix + '-level value');
  AddLineToQueue('sqlquery sql_query;');
  AddLineToQueue('string ' + varname + ' = "";');
  AddLineToQueue('sql_query = ' + query_func + '();');
  AddLineToQueue('');
  AddLineToQueue('// Execute: SELECT value FROM variables WHERE key=?');
  AddLineToQueue('SqlBindString(sql_query, 1, "' + key + '");');
  AddLineToQueue('');
  AddLineToQueue('if (SqlStep(sql_query) == SQL_ROW)');
  AddLineToQueue('  ' + varname + ' = SqlGetString(sql_query, 0);');
  AddLineToQueue('else');
  AddLineToQueue('  SqlDebug("Variable not found: ' + key + '");');
  AddLineToQueue('');
  AddLineToQueue('SqlDebug("Retrieved: " + ' + varname + ');');

  OutputToScript;
end;

procedure TsqlitegenForm.OutputToScript;
var
  i: integer;
begin
  MemoOutput.Clear;
  for i := 0 to High(QueuedLines) do
    MemoOutput.Lines.Add(QueuedLines[i]);
end;

procedure TsqlitegenForm.ButtonSetValueClick(Sender: TObject);
begin
  GenerateSetValue;
end;

procedure TsqlitegenForm.ButtonGetValueClick(Sender: TObject);
begin
  GenerateGetValue;
end;

procedure TsqlitegenForm.ButtonCloseClick(Sender: TObject);
var
  i: integer;
begin
  { Add the queued lines directly to the main script window }
  for i := 0 to High(QueuedLines) do
    main.scriptwindow.Lines.Add(QueuedLines[i]);
  
  Close;
end;

end.
