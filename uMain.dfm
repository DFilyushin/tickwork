object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Tickwork'
  ClientHeight = 480
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlNew: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 92
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblNewTitle: TLabel
      Left = 8
      Top = 8
      Width = 20
      Height = 13
      Caption = 'Title'
    end
    object lblNewType: TLabel
      Left = 408
      Top = 8
      Width = 24
      Height = 13
      Caption = 'Type'
    end
    object lblNewJira: TLabel
      Left = 576
      Top = 8
      Width = 17
      Height = 13
      Caption = 'Jira'
    end
    object edtTitle: TEdit
      Left = 8
      Top = 24
      Width = 385
      Height = 21
      TabOrder = 0
    end
    object cbType: TComboBox
      Left = 408
      Top = 24
      Width = 153
      Height = 21
      Style = csDropDownList
      TabOrder = 1
    end
    object edtJira: TEdit
      Left = 576
      Top = 24
      Width = 129
      Height = 21
      CharCase = ecUpperCase
      TabOrder = 2
    end
    object chkStartNow: TCheckBox
      Left = 8
      Top = 58
      Width = 249
      Height = 17
      Caption = 'Start now'
      Checked = True
      State = cbChecked
      TabOrder = 3
    end
    object btnCreate: TButton
      Left = 576
      Top = 54
      Width = 129
      Height = 25
      Caption = 'Create'
      Default = True
      TabOrder = 4
      OnClick = btnCreateClick
    end
  end
  object lvTasks: TListView
    Left = 0
    Top = 92
    Width = 720
    Height = 316
    Align = alClient
    Columns = <
      item
        Caption = 'Task'
        Width = 280
      end
      item
        Caption = 'Type'
        Width = 120
      end
      item
        Caption = 'Jira'
        Width = 90
      end
      item
        Caption = 'Status'
        Width = 90
      end
      item
        Caption = 'Time'
        Width = 90
      end>
    ColumnClick = False
    GridLines = True
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    PopupMenu = pmTasks
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = lvTasksDblClick
    OnSelectItem = lvTasksSelectItem
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 408
    Width = 720
    Height = 72
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lblUnsynced: TLabel
      Left = 8
      Top = 46
      Width = 3
      Height = 13
    end
    object btnStartPause: TButton
      Left = 8
      Top = 8
      Width = 121
      Height = 25
      Caption = 'Start'
      TabOrder = 0
      OnClick = btnStartPauseClick
    end
    object btnComplete: TButton
      Left = 135
      Top = 6
      Width = 121
      Height = 25
      Caption = 'Complete'
      TabOrder = 1
      OnClick = btnCompleteClick
    end
    object btnReports: TButton
      Left = 488
      Top = 8
      Width = 105
      Height = 25
      Caption = 'Reports'
      TabOrder = 2
      OnClick = btnReportsClick
    end
    object btnSettings: TButton
      Left = 600
      Top = 8
      Width = 105
      Height = 25
      Caption = 'Settings'
      TabOrder = 3
      OnClick = btnSettingsClick
    end
    object btnResend: TButton
      Left = 488
      Top = 40
      Width = 217
      Height = 25
      Caption = 'Resend'
      TabOrder = 4
      Visible = False
      OnClick = btnResendClick
    end
  end
  object trayIcon: TTrayIcon
    PopupMenu = pmTray
    Visible = True
    OnDblClick = trayIconDblClick
    Left = 48
    Top = 152
  end
  object pmTray: TPopupMenu
    OnPopup = pmTrayPopup
    Left = 120
    Top = 152
    object miOpen: TMenuItem
      Caption = 'Open'
      Default = True
      OnClick = miOpenClick
    end
    object miTraySep1: TMenuItem
      Caption = '-'
    end
    object miPause: TMenuItem
      Caption = 'Pause'
      OnClick = miPauseClick
    end
    object miResume: TMenuItem
      Caption = 'Resume'
      OnClick = miResumeClick
    end
    object miSwitch: TMenuItem
      Caption = 'Switch'
    end
    object miTraySep2: TMenuItem
      Caption = '-'
    end
    object miTraySettings: TMenuItem
      Caption = 'Settings'
      OnClick = btnSettingsClick
    end
    object miTrayReports: TMenuItem
      Caption = 'Reports'
      OnClick = btnReportsClick
    end
    object miTraySep3: TMenuItem
      Caption = '-'
    end
    object miExit: TMenuItem
      Caption = 'Exit'
      OnClick = miExitClick
    end
  end
  object pmTasks: TPopupMenu
    OnPopup = pmTasksPopup
    Left = 192
    Top = 152
    object miTaskStartPause: TMenuItem
      Caption = 'Start / Pause'
      OnClick = btnStartPauseClick
    end
    object miTaskComplete: TMenuItem
      Caption = 'Complete'
      OnClick = btnCompleteClick
    end
    object miTaskEdit: TMenuItem
      Caption = 'Edit...'
      OnClick = miTaskEditClick
    end
    object miTaskAddTime: TMenuItem
      Caption = 'Add time...'
      OnClick = miTaskAddTimeClick
    end
    object miTaskSep: TMenuItem
      Caption = '-'
    end
    object miTaskDelete: TMenuItem
      Caption = 'Delete'
      OnClick = miTaskDeleteClick
    end
  end
  object tmrUI: TTimer
    OnTimer = tmrUITimer
    Left = 264
    Top = 152
  end
  object tmrHeartbeat: TTimer
    Interval = 60000
    OnTimer = tmrHeartbeatTimer
    Left = 336
    Top = 152
  end
end
