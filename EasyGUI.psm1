Write-Host "Checking PowerShell version Requirement . . ."

# Requires PS 5.1 or 7+ (but not 6.x)
$PSMajor = $PSVersionTable.PSVersion.Major
$OS = [System.Environment]::OSVersion.Platform

# Block unsupported OS first
if ($OS -ne 'Win32NT') {
    Write-Error "EasyGUI only supports Windows. Your current OS: $OS"
    return
}

# Block PowerShell older than 5.1
if ($PSMajor -lt 5 -or ($PSMajor -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
    Write-Error "EasyGUI requires at least PowerShell 5.1."
    return
}

# Block PowerShell 6.x
if ($PSMajor -eq 6) {
    Write-Error "EasyGUI does NOT support PowerShell 6.x. Please install PowerShell 7 or use Windows PowerShell 5.1."
    return
}

# Passed
Write-Host "EasyGUI System and PowerShell Requirement Passed." -ForegroundColor Green



Write-Verbose "Adding Required Assembly / Type Names . . ."
try {
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
} catch {
    Write-Error "Oops something went wrong: $_"
}
function Add-ErrorMessage {
param($ErrorMessage)
    Write-Error "Oops a Error Have occurred: `n $ErrorMessage"
    
    [System.Windows.MessageBox]::Show(
        "Oops a Error Have occurred",
        "Error: $ErrorMessage",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Error
        )

    return

}

function PrepareWindow {
    param(
        [string]$Title = "Untitled GUI",
        [int]$Width = 500,
        [int]$Height = 400
    )

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title"
        Height="$Height"
        Width="$Width"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E"
        FontFamily="Segoe UI"
        ResizeMode="NoResize">
    
    <Grid Margin="10">
        <!-- ScrollViewer fills entire Grid -->
        <ScrollViewer VerticalScrollBarVisibility="Hidden" 
                      HorizontalScrollBarVisibility="Disabled"
                      HorizontalAlignment="Stretch" 
                      VerticalAlignment="Stretch"
                      Background="#1E1E1E">
            <!-- Inner StackPanel holds content -->
            <StackPanel x:Name="Stack" VerticalAlignment="Top" />
        </ScrollViewer>
    </Grid>
</Window>
"@

    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
        $script:Window = [Windows.Markup.XamlReader]::Load($reader)
        $global:Stack = $script:Window.FindName("Stack")
    }
    catch {
        Write-Host "Error creating WPF window: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    return $true
}

function Window.Text {
    param(
        [string]$Content,
        [string]$foreground = "White",
        [string]$ID = $null  # Optional unique ID for updating
    )

    if (-not $global:Stack) { Write-Host "GUI not initialized"; return }

    # Make sure Inputs hash exists
    if (-not ($script:Window | Get-Member -Name Inputs)) {
        $script:Window | Add-Member -MemberType NoteProperty -Name Inputs -Value @{}
    }

    if ($ID) {
        # Ensure the hashtable itself exists
        if (-not $script:Window.Inputs) {
            $script:Window.Inputs = @{}
        }

        # If TextBlock already exists, just update
        if ($script:Window.Inputs.ContainsKey($ID)) {
            $script:Window.Inputs[$ID].Text = $Content
            return
        }
    }

    # Create a new TextBlock
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Content
    $label.Foreground = $foreground
    $label.Margin = "5,5,5,10"
    $label.FontSize = 16

    # Store reference if ID given
    if ($ID) {
        $script:Window.Inputs[$ID] = $label
    }

    $global:Stack.Children.Add($label)
}



function Window.AddButton {
    param(
        [string]$Name,
        [scriptblock]$Command
    )
    if (-not $global:Stack) { Write-Host "GUI not initialized"; return }

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $Name
    $btn.Height = 35
    $btn.Width = 200
    $btn.HorizontalAlignment = "Left"
    $btn.Background = "#2A2A2A"
    $btn.Foreground = "White"
    $btn.BorderBrush = "#444"
    $btn.BorderThickness = 1
    $btn.Padding = "10,6"
    $btn.Margin = "4"
    $btn.FontSize = 14
    $btn.Cursor = "Hand"
      # Hover
    $btn.Add_MouseEnter({ $_.Source.Background = "#3A3A3A" })
    $btn.Add_MouseLeave({ $_.Source.Background = "#2A2A2A" })

    # Pressed
    $btn.Add_PreviewMouseDown({ $_.Source.Background = "#3A7BFF" })
    $btn.Add_PreviewMouseUp({ if (-not $_.Source.IsMouseOver) { $_.Source.Background = "#2A2A2A" } })

    $localCommand = $Command
    $btn.Add_Click({
        if ([string]::IsNullOrWhiteSpace($localCommand)) {
            [System.Windows.MessageBox]::Show("Oops a Error Have occurred: No command assigned.")
            return
        }
        try { & $localCommand }
        catch { [System.Windows.MessageBox]::Show("Error: $($_.Exception.Message)") }
    }.GetNewClosure())

    $global:Stack.Children.Add($btn)
}

function Window.AddInputBox {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID,

        [Parameter(Mandatory=$false)]
        [scriptblock]$Action
    )

    # Ensure custom storage exists
    if (-not ($script:Window | Get-Member -Name Inputs)) {
        $script:Window | Add-Member -MemberType NoteProperty -Name Inputs -Value @{}
    }
    if (-not ($script:Window | Get-Member -Name InputActions)) {
        $script:Window | Add-Member -MemberType NoteProperty -Name InputActions -Value @{}
    }

    # Ensure valid Name (must start with a letter)
    $nameSafe = "Input$ID"

    # Create TextBox
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Name = $nameSafe

    # Easy GUI style
    $tb.Background      = "#222"
    $tb.Foreground      = "White"
    $tb.BorderBrush     = "#555"
    $tb.BorderThickness = 1
    $tb.FontSize        = 14
    $tb.Padding         = "6"
    $tb.Margin          = "4"

    # Focus border change
    $tb.Add_GotFocus({ $_.Source.BorderBrush = "#3A7BFF" })
    $tb.Add_LostFocus({ $_.Source.BorderBrush = "#555" })

    # Hover effect
    $tb.Add_MouseEnter({ $_.Source.Background = "#2E2E2E" })
    $tb.Add_MouseLeave({ $_.Source.Background = "#222" })

    # Store input reference
    $script:Window.Inputs[$ID] = $tb

    # Store optional action
    if ($Action) {
        $script:Window.InputActions[$ID] = $Action
    }

    # Add automatically to current StackPanel if exists
    if ($global:Stack) { $global:Stack.Children.Add($tb) }

    return $tb
}


function Window.InputApply {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputID,

        [Parameter(Mandatory=$false)]
        [string]$ButtonLabel = "Apply",

        [Parameter(Mandatory=$false)]
        [string]$Alignment = "Left"  # HorizontalAlignment: Left, Center, Right
    )

    # Ensure the input exists
    if (-not $script:Window.Inputs.ContainsKey($InputID)) {
        [System.Windows.MessageBox]::Show("Input '$InputID' not found.")
        return
    }

    # Create the button
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $ButtonLabel
    $btn.Height = 35
    $btn.Width = 200
    $btn.Margin = "4"
    $btn.FontSize = 14
    $btn.HorizontalAlignment = $Alignment
    $btn.Background = "#2A2A2A"
    $btn.Foreground = "White"
    $btn.BorderBrush = "#444"
    $btn.BorderThickness = 1
    $btn.Cursor = "Hand"

    # Hover effect
    $btn.Add_MouseEnter({ $_.Source.Background = "#3A3A3A" })
    $btn.Add_MouseLeave({ $_.Source.Background = "#2A2A2A" })
    # Pressed effect
    $btn.Add_PreviewMouseDown({ $_.Source.Background = "#3A7BFF" })
    $btn.Add_PreviewMouseUp({ if (-not $_.Source.IsMouseOver) { $_.Source.Background = "#2A2A2A" } })

    # Click action: run stored InputAction if exists
    $btn.Add_Click({
        if ($script:Window.InputActions.ContainsKey($InputID)) {
            & $script:Window.InputActions[$InputID]
        } else {
            [System.Windows.MessageBox]::Show("No action defined for Input '$InputID'.")
        }
    }.GetNewClosure())

    # Add button to the current stack panel
    if ($global:Stack) { $global:Stack.Children.Add($btn) }
}








function Window.AddOption {
    param(
        [string]$Label,
        [string]$ID = "default",
        [string]$Mini = "$false",
        [string]$align = "Left",
        [string]$tooltip,
        [int]$Margin = 8,
        [bool]$Default = $false,
        [scriptblock]$Action = {}
        
        
    )

    $ID = if ($ID) { [string]$ID } else { "default" }
    $Label = if ($Label) { $Label } else { "Option" }

    # Ensure group exists
    if (-not $global:Options.ContainsKey($ID)) {
        $global:Options[$ID] = @{}
    }

    # Store state and action in global:Options
    $global:Options[$ID][$Label] = @{
        Checked = $Default
        Action  = $Action
    }
    

    # Create the checkbox
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $Label
    $cb.IsChecked = $Default
    $cb.HorizontalAlignment = $align
    if ($tooltip) {
        $cb.tooltip = $tooltip
    }
    
    $cb.Cursor = "Hand"
    $cb.Foreground = "White"
    $cb.FontSize   = 14
    $cb.Margin     = $Margin

    # Box (Border) styling
    $cb.BorderBrush = "#777"
    $cb.BorderThickness = 2
    $cb.Background = "#222"

    # Hover effect
    $cb.Add_MouseEnter({ $_.Source.BorderBrush = "#999" })
    $cb.Add_MouseLeave({ $_.Source.BorderBrush = "#777" })
    
    $cb.Add_Checked({ 
        $_.Source.Background   = "#00b100"
        $_.Source.BorderBrush  = "#00b100"
    })

    $cb.Add_Unchecked({ 
        $_.Source.Background   = "#222"
        $_.Source.BorderBrush  = "#777"
    })

    # Tag stores label and group reference only
    
    $cb.Tag = @{
        Label = $Label
        Group = $global:Options[$ID]
    }

    # Update global hash when checked/unchecked
    $cb.Add_Checked({
        $tag = $_.Source.Tag
        $tag.Group[$tag.Label].Checked = $true
    })
    $cb.Add_Unchecked({
        $tag = $_.Source.Tag
        $tag.Group[$tag.Label].Checked = $false
    })

    # Apply Action Now

    if ($ActionNowCheck) {
            $cb.Add_Checked({
     & $ActionNow   
            })
    }

    $global:Stack.Children.Add($cb) | Out-Null
}





function Window.AddTabControl {
    if (-not $global:Stack) { Write-Host "GUI not initialized"; return }

    $tabControl = New-Object System.Windows.Controls.TabControl
    $tabControl.Margin = "0,10,0,0"
    $tabControl.Height = 300
    $tabControl.Background = "#1E1E1E"
    $tabControl.BorderBrush = "#1E1E1E"
    $tabControl.TabStripPlacement = "Top"
    $tabControl.Padding = "5,2,5,2"
    $tabControl.BorderThickness = 0
    $global:Stack.Children.Add($tabControl)
    $global:Tabs = $tabControl
    
}

function Window.AddTab {
    param(
        [string]$Label,
        [scriptblock]$Script
    )
    if (-not $global:Tabs) { Write-Host "TabControl not created"; return }

    $tabItem = New-Object System.Windows.Controls.TabItem
    $tabItem.Header = $Label
    $tabItem.Foreground = "#AAA"
    $tabItem.Background = "#1E1E1E"
    $tabItem.FontWeight = "Bold"

       # base style
    $tabItem.Background = "#222"
    $tabItem.BorderBrush = "#333"
    $tabItem.BorderThickness = 1
    $tabItem.Margin = "2,0"
    $tabItem.Padding = "12,6"
    $tabItem.Foreground = "#CCCCCC"
    $tabItem.FontSize = 14

    # hover
    $tabItem.Add_MouseEnter({
        if (-not $_.Source.IsSelected) {
            $_.Source.Background = "#333"
        }
    })

    $tabItem.Add_MouseLeave({
        if (-not $_.Source.IsSelected) {
            $_.Source.Background = "#222"
        }
    })




    # --- NEW: Create scrollable content for the tab ---
    $containerGrid = New-Object System.Windows.Controls.Grid
    $containerGrid.HorizontalAlignment = "Stretch"
    $containerGrid.VerticalAlignment = "Stretch"

    $row = New-Object System.Windows.Controls.RowDefinition
    $row.Height = "*"
    $containerGrid.RowDefinitions.Add($row)
    $col = New-Object System.Windows.Controls.ColumnDefinition
    $col.Width = "*"
    $containerGrid.ColumnDefinitions.Add($col)

    $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Hidden"  # hides scrollbar
    $scrollViewer.HorizontalScrollBarVisibility = "Disabled"
    $scrollViewer.HorizontalAlignment = "Stretch"
    $scrollViewer.VerticalAlignment = "Stretch"
    $scrollViewer.Background = "#1E1E1E"

    $scrollStack = New-Object System.Windows.Controls.StackPanel
    $scrollStack.Margin = "5"
    $scrollStack.Background = "#1E1E1E"

    $scrollViewer.Content = $scrollStack
    $containerGrid.Children.Add($scrollViewer)
    [System.Windows.Controls.Grid]::SetRow($scrollViewer,0)
    [System.Windows.Controls.Grid]::SetColumn($scrollViewer,0)

    $tabItem.Content = $containerGrid
    # --- END NEW ---

    $global:Tabs.Items.Add($tabItem)

    # Temporarily redirect global stack to inner scrollable StackPanel
    $oldStack = $global:Stack
    $global:Stack = $scrollStack

    # Execute the user-provided scriptblock
    & $Script

    # Restore original stack
    $global:Stack = $oldStack
}


function Window.AddRadioButtonApply {
    param(
        [string]$Label,
        [string]$ID
    )

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $Label
    $btn.Height = 35
    $btn.Width = 200
    $btn.Margin = "5"
    $btn.FontSize = 13
    $btn.Foreground = "White"
    $btn.Background = "#2D2D30"
    $btn.BorderBrush = "#3C3C3C"
    $btn.Cursor = "Hand"

    $localID = $ID

    $btn.Add_Click({
        if (-not $global:Options.ContainsKey($localID)) {
            [System.Windows.MessageBox]::Show("No radio options exist for group '$localID'")
            return
        }

        # Find the selected option in the hash
        $selected = $global:Options[$localID].GetEnumerator() |
                    Where-Object { $_.Value.Checked } |
                    Select-Object -ExpandProperty Key

        if (-not $selected) {
            [System.Windows.MessageBox]::Show("No option selected for group '$localID'.")
            return
        }

        # Execute the action stored in global:Options
        $action = $global:Options[$localID][$selected].Action
        if ($action) {
            & $action
        } else {
            Write-Host "No action defined for selected radio: $selected"
        }
    }.GetNewClosure())

    $global:Stack.Children.Add($btn) | Out-Null
}



function Window.AddRadioOption {
    param(
        [string]$Label,
        [string]$ID = "default",
        [bool]$Default = $false,
        [scriptblock]$Action = {}
    )

    # Ensure group exists
    if (-not $global:Options.ContainsKey($ID)) {
        $global:Options[$ID] = @{}
    }

    # Store the radio option in global:Options
    $global:Options[$ID][$Label] = @{
        Checked = $Default
        Action  = $Action
    }

    # Create the RadioButton control
    $rb = New-Object System.Windows.Controls.RadioButton
    $rb.Content = $Label
    $rb.GroupName = $ID
    $rb.IsChecked = $Default
    $rb.Margin = "0,5,0,5"
    $rb.Cursor = "Hand"
    $rb.Foreground = "White"
    $rb.FontSize   = 14
    $rb.Margin     = "4"

    # Outer ring
    $rb.BorderBrush = "#777"
    $rb.BorderThickness = 2
    $rb.Background = "#777"

    # Hover
    $rb.Add_MouseEnter({ $_.Source.BorderBrush = "#999" })
    $rb.Add_MouseLeave({ $_.Source.BorderBrush = "#777" })

    # Checked
    $rb.Add_Checked({
        $_.Source.BorderBrush = "#3A7BFF"
    })
    $rb.Add_Unchecked({
        $_.Source.BorderBrush = "#777"
    })

    # Tag stores the label and group reference (no Action here)
    $rb.Tag = @{
        Label = $Label
        Group = $global:Options[$ID]
    }

    # When checked, update the Checked field in global:Options
    $rb.Add_Checked({
        $tag = $_.Source.Tag
        $group = $tag.Group
        $label = $tag.Label

        # Only this label is true; all others false
        foreach ($key in @($group.Keys)) {
            $group[$key].Checked = ($key -eq $label)
        }
    })

    $global:Stack.Children.Add($rb) | Out-Null
}

function Window.AddDropDown {
    param(
        [Parameter(Mandatory)]
        [string]$ID,

        [Parameter(Mandatory)]
        [array]$Items,

        [Parameter()]
        [scriptblock]$Action = $null,

        [Parameter()]
        [string]$Label = "",

        [Parameter()]
        [int]$Width = 200,

        [Parameter()]
        [int]$Height = 28,

        [Parameter()]
        [string]$DisplayMember = "Display"  # Property to show in ComboBox
    )

    # Ensure inputs and actions tables exist
    if (-not ($script:Window | Get-Member -Name Inputs)) {
        $script:Window | Add-Member -MemberType NoteProperty -Name Inputs -Value @{}
    }
    if (-not ($script:Window | Get-Member -Name InputActions)) {
        $script:Window | Add-Member -MemberType NoteProperty -Name InputActions -Value @{}
    }

    # Optional label
    if ($Label) {
        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $Label
        $lbl.Margin = "5,5,5,0"
        $lbl.Foreground = [System.Windows.Media.Brushes]::White
        $lbl.FontSize = 14
        $global:Stack.Children.Add($lbl)
    }

    # Create ComboBox
    $combo = New-Object System.Windows.Controls.ComboBox
    $combo.Width = $Width
    $combo.Height = $Height
    $combo.Margin = "5"
    $combo.Background = "#222"
    $combo.Foreground = "White"
    $combo.BorderBrush = "#555"
    $combo.BorderThickness = 1
    $combo.Cursor = "Hand"

    # If items are objects and DisplayMember exists, bind it
    if ($Items -and $Items[0] -is [PSCustomObject] -and $Items[0].PSObject.Properties[$DisplayMember]) {
        $combo.DisplayMemberPath = $DisplayMember
        $combo.ItemsSource = $Items
    } else {
        $combo.ItemsSource = $Items
    }

    # Hover/focus effects
    $combo.Add_GotFocus({ $_.Source.BorderBrush = "#3A7BFF" })
    $combo.Add_LostFocus({ $_.Source.BorderBrush = "#555" })
    $combo.Add_MouseEnter({ $_.Source.Background = "#2E2E2E" })
    $combo.Add_MouseLeave({ $_.Source.Background = "#222" })

    # Store reference
    $script:Window.Inputs[$ID] = $combo
    if ($Action) { $script:Window.InputActions[$ID] = $Action }

    # Add Apply button next to dropdown
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Orientation = "Horizontal"
    $panel.Margin = "0,2,0,5"
    $panel.Children.Add($combo)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "Apply"
    $btn.Width = 80
    $btn.Height = $Height
    $btn.Margin = "8,0,0,0"
    $btn.FontSize = 13
    $btn.Background = "#2A2A2A"
    $btn.Foreground = "White"
    $btn.BorderBrush = "#444"
    $btn.Cursor = "Hand"

    $btn.Add_MouseEnter({ $_.Source.Background = "#3A3A3A" })
    $btn.Add_MouseLeave({ $_.Source.Background = "#2A2A2A" })
    $btn.Add_PreviewMouseDown({ $_.Source.Background = "#3A7BFF" })
    $btn.Add_PreviewMouseUp({ if (-not $_.Source.IsMouseOver) { $_.Source.Background = "#2A2A2A" } })

    $localID = $ID
    $btn.Add_Click({
        $selected = $script:Window.Inputs[$localID].SelectedItem
        if ($null -ne $selected) {
            if ($script:Window.InputActions.ContainsKey($localID)) {
                & $script:Window.InputActions[$localID] -ArgumentList $selected
            } else {
                [System.Windows.MessageBox]::Show("No action defined for '$localID'.")
            }
        } else {
            [System.Windows.MessageBox]::Show("Please select an item first.")
        }
    }.GetNewClosure())

    $panel.Children.Add($btn)
    $global:Stack.Children.Add($panel)
}



function Window.AddSuperApplyButton {
    param(
        [string]$Label,
        [string[]]$Groups  # Array of Option/Radio group IDs
    )

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $Label
    $btn.Height = 35
    $btn.Width = 250
    $btn.Margin = "5"
    $btn.FontSize = 13
    $btn.Background = "#2D2D30"
    $btn.Foreground = "White"
    $btn.BorderBrush = "#3C3C3C"
    $btn.HorizontalAlignment = "Center"
    $btn.Cursor = "Hand"

    $btn.Add_Click({
        foreach ($ID in $Groups) {
            if (-not $global:Options.ContainsKey($ID)) {
                Write-Host "No options found for group '$ID'"
                continue
            }

            # Apply all checked options in this group
            $selected = $global:Options[$ID].GetEnumerator() |
                        Where-Object { $_.Value.Checked } |
                        Select-Object -ExpandProperty Key

            foreach ($opt in $selected) {
                $action = $global:Options[$ID][$opt].Action
                if ($action) {
                    & $action
                }
            }

            Write-Host "Group '$ID' applied: $($selected -join ', ')"
        }

        [System.Windows.MessageBox]::Show("Applied groups: $($Groups -join ', ')")
    }.GetNewClosure())

    $global:Stack.Children.Add($btn) | Out-Null
}


function Window.AddApplyOptionButton {
    param(
        [string]$Label = "Option Apply Button",
        [string]$ID = "default",
        [string]$Alignment = "Left"
    )

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $Label
    $btn.Margin = "5"
    $btn.Height = 35
    $btn.Width = 200
    $btn.FontSize = 13
    $btn.Background = "#2D2D30"
    $btn.Foreground = "White"
    $btn.BorderBrush = "#3C3C3C"
    $btn.HorizontalAlignment = $Alignment
    $btn.Cursor = "Hand"

    $localID = $ID

    $btn.Add_Click({
        if (-not $global:Options.ContainsKey($localID)) {
            [System.Windows.MessageBox]::Show("No options found for ID '$localID'.")
            return
        }

        # Get all checked options
        $selected = $global:Options[$localID].GetEnumerator() |
                    Where-Object { $_.Value.Checked } |
                    Select-Object -ExpandProperty Key

        if (-not $selected) {
            [System.Windows.MessageBox]::Show("No options selected for group '$localID'.")
            return
        }

        # Run actions for all checked options
        foreach ($opt in $selected) {
            $action = $global:Options[$localID][$opt].Action
            if ($action) { & $action }
        }

        # Optional: show selected
        [System.Windows.MessageBox]::Show("Selected options:`n$($selected -join "`n")")
        Write-Host "Selected options:" $selected
    }.GetNewClosure())

     $global:Stack.Children.Add($btn) | Out-Null
}

function Window.Close {
    if ($script:Window) {
        $script:Window.Close()
    }
}

function Window.ControlLockCheckBox {
    param(
        [string]$ID,
        [string]$Label,
        [bool]$Lock = $true  # $true = lock, $false = unlock
    )

    if (-not $global:Options.ContainsKey($ID)) { return }

    # Find the control in the StackPanel
    foreach ($child in $global:Stack.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.Tag.Label -eq $Label) {
            $child.IsEnabled = -not $Lock
            return
        }
    }
}

function Window.ControlLockEntireRadioID {
    param(
        [string]$ID,
        [bool]$Lock = $true
    )

    if (-not $global:Options.ContainsKey($ID)) { return }

    # Iterate through all controls in the StackPanel
    foreach ($child in $global:Stack.Children) {
        if ($child -is [System.Windows.Controls.RadioButton]) {
            $tag = $child.Tag
            if ($tag.GroupID -eq $ID) {
                $child.IsEnabled = -not $Lock
            }
        }
    }
}



function IsOptionChecked {
    param(
        [string]$ID,
        [string]$Label
    )

    return ($global:Options[$ID][$Label].Checked -eq $true)
    #Usage: Use in If () {}
}

function Select-Path {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("OpenFile","SaveFile","PickFolder")]
        [string]$Mode,

        [string]$Title = "Select item",
        [string]$Filter = "All files (*.*)|*.*",
        [string]$DefaultFileName = "NewFile.txt",
        [string]$InitialDirectory = [Environment]::GetFolderPath("Desktop")
    )

    switch ($Mode) {
        "OpenFile" {
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Title = $Title
            $dlg.Filter = $Filter
            $dlg.InitialDirectory = $InitialDirectory
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                return $dlg.FileName
            }
        }
        "SaveFile" {
            $dlg = New-Object System.Windows.Forms.SaveFileDialog
            $dlg.Title = $Title
            $dlg.Filter = $Filter
            $dlg.FileName = $DefaultFileName
            $dlg.InitialDirectory = $InitialDirectory
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                return $dlg.FileName
            }
        }
        "PickFolder" {
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlg.Description = $Title
            $dlg.SelectedPath = $InitialDirectory
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                return $dlg.SelectedPath
            }
        }
    }
}

function ShowWindow {
    if (-not $script:Window) { Write-Host "No window created."; return }
    $null = $script:Window.ShowDialog()
}

function Get-GUIWindow {
    return $script:Window
}

function Set-GUIWindow {
    param([Parameter(Mandatory)]$NewValue)
    $script:Window = $NewValue
}


Write-Host "All GUI Functions Sucessfully loaded." -ForegroundColor Green
