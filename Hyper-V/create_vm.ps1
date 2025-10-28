Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Formular
$form = New-Object System.Windows.Forms.Form
$form.Text = "Neue VM in Hyper-V erstellen"
$form.Size = New-Object System.Drawing.Size(500,410)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI",10)

# Labels & Eingabefelder
$labels = @("VM-Name:", "VM-Pfad:", "RAM (MB):", "VHD-Größe (GB):", "ISO-Pfad:")
$fields = @()

for ($i=0; $i -lt $labels.Count; $i++) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $labels[$i]
    $label.Location = New-Object System.Drawing.Point(20,(25 + $i*50))
    $label.Size = New-Object System.Drawing.Size(120,25)
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(150,(25 + $i*50))
    $textbox.Size = New-Object System.Drawing.Size(250,25)
    $form.Controls.Add($textbox)
    $fields += $textbox

    # Buttons für Pfadauswahl
    if ($i -eq 1 -or $i -eq 4) {
        $browseButton = New-Object System.Windows.Forms.Button
        $browseButton.Text = "..."
        $browseButton.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
        $browseButton.Location = New-Object System.Drawing.Point(410,(23 + $i*50))
        $browseButton.Size = New-Object System.Drawing.Size(40,27)

        if ($i -eq 1) {
            $browseButton.Add_Click({
                $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderDialog.Description = "Speicherort für VM-Dateien auswählen"
                if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $fields[1].Text = $folderDialog.SelectedPath
                }
            })
        }

        if ($i -eq 4) {
            $browseButton.Add_Click({
                $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
                $fileDialog.Filter = "ISO-Dateien (*.iso)|*.iso|Alle Dateien (*.*)|*.*"
                $fileDialog.Title = "ISO-Datei auswählen"
                $fileDialog.InitialDirectory = "D:\"
                if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $fields[4].Text = $fileDialog.FileName
                }
            })
        }

        $form.Controls.Add($browseButton)
    }
}

# Checkbox für Autostart mit Zeilenumbruch
$chkStart = New-Object System.Windows.Forms.CheckBox
$chkStart.Text = "VM nach Erstellung automatisch starten"
$chkStart.Location = New-Object System.Drawing.Point(20,290)
$chkStart.Size = New-Object System.Drawing.Size(440,40)
$chkStart.AutoSize = $false
$chkStart.TextAlign = 'TopLeft'
$form.Controls.Add($chkStart)

# OK-Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "Erstellen"
$okButton.Location = New-Object System.Drawing.Point(190,340)
$okButton.Size = New-Object System.Drawing.Size(100,30)
$okButton.Add_Click({ $form.Close() })
$form.Controls.Add($okButton)

# Formular anzeigen
$form.ShowDialog() | Out-Null

# Eingaben übernehmen
$VMName   = $fields[0].Text
$VMPath   = $fields[1].Text
$VMMemory = [int]$fields[2].Text
$VHDSize  = [int]$fields[3].Text
$ISOPath  = $fields[4].Text
$AutoStart = $chkStart.Checked

# --- Erstellung ---
$VMFullPath = "$VMPath\$VMName"
$VHDPath    = "$VMFullPath\$VMName.vhdx"

if ((Get-Service -Name vmms).Status -ne "Running") { Start-Service -Name vmms }
if (!(Test-Path $VMFullPath)) { New-Item -Path $VMFullPath -ItemType Directory | Out-Null }

New-VHD -Path $VHDPath -SizeBytes ($VHDSize * 1GB) -Dynamic | Out-Null
New-VM -Name $VMName -MemoryStartupBytes ($VMMemory * 1MB) -Generation 2 -VHDPath $VHDPath -Path $VMFullPath | Out-Null
if (Test-Path $ISOPath) { Add-VMDvdDrive -VMName $VMName -Path $ISOPath | Out-Null }

if ($AutoStart) { Start-VM -Name $VMName }

[System.Windows.Forms.MessageBox]::Show("VM '$VMName' wurde erfolgreich erstellt.","Fertig")
