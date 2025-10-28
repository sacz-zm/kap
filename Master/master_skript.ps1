# ==========================================
#  Kursabschlussprojekt Modul 03
#  Master-Menü für PowerShell-Automatisierungen
#  Autor: Sascha
# ==========================================

function Show-Menu {
    Clear-Host
    Write-Host "==============================="
    Write-Host "     ADMIN-MASTER-SKRIPT"
    Write-Host "==============================="
    Write-Host "1. Neue VM in Hyper-V erstellen (GUI)"
    Write-Host "2. AD-Benutzer erstellen"
    Write-Host "3. Organisationseinheit (OU) anlegen"
    Write-Host "4. AD-Gruppe anlegen"
    Write-Host "5. Benutzer zu Gruppe hinzufügen"
    Write-Host "6. Mehrere Benutzer aus Excel importieren"
    Write-Host "7. Netzwerkkarte mit fester IP konfigurieren"
    Write-Host "8. Lokalen Benutzer anlegen"
    Write-Host "0. Beenden"
    Write-Host "==============================="
}

# --- 1. VM-Erstellung (GUI) ---
function New-VM-GUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Neue VM in Hyper-V erstellen"
    $form.Size = New-Object System.Drawing.Size(500,410)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI",10)

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

        if ($i -eq 1 -or $i -eq 4) {
            $browseButton = New-Object System.Windows.Forms.Button
            $browseButton.Text = "..."
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

    $chkStart = New-Object System.Windows.Forms.CheckBox
    $chkStart.Text = "VM nach Erstellung automatisch starten"
    $chkStart.Location = New-Object System.Drawing.Point(20,290)
    $chkStart.Size = New-Object System.Drawing.Size(440,40)
    $form.Controls.Add($chkStart)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Erstellen"
    $okButton.Location = New-Object System.Drawing.Point(190,340)
    $okButton.Size = New-Object System.Drawing.Size(100,30)
    $okButton.Add_Click({ $form.Close() })
    $form.Controls.Add($okButton)

    $form.ShowDialog() | Out-Null

    $VMName   = $fields[0].Text
    $VMPath   = $fields[1].Text
    $VMMemory = [int]$fields[2].Text
    $VHDSize  = [int]$fields[3].Text
    $ISOPath  = $fields[4].Text
    $AutoStart = $chkStart.Checked

    $VMFullPath = "$VMPath\$VMName"
    $VHDPath    = "$VMFullPath\$VMName.vhdx"

    if ((Get-Service -Name vmms).Status -ne "Running") { Start-Service -Name vmms }
    if (!(Test-Path $VMFullPath)) { New-Item -Path $VMFullPath -ItemType Directory | Out-Null }

    New-VHD -Path $VHDPath -SizeBytes ($VHDSize * 1GB) -Dynamic | Out-Null
    New-VM -Name $VMName -MemoryStartupBytes ($VMMemory * 1MB) -Generation 2 -VHDPath $VHDPath -Path $VMFullPath | Out-Null
    if (Test-Path $ISOPath) { Add-VMDvdDrive -VMName $VMName -Path $ISOPath | Out-Null }
    if ($AutoStart) { Start-VM -Name $VMName }

    [System.Windows.Forms.MessageBox]::Show("VM '$VMName' wurde erfolgreich erstellt.","Fertig")
}

# --- 2. AD-Benutzer ---
function New-ADUserSimple {
    $Name = Read-Host "Benutzername"
    $OU = Read-Host "OU-Pfad (z. B. OU=Vertrieb,DC=firma,DC=local)"
    $Password = Read-Host "Kennwort" -AsSecureString
    New-ADUser -Name $Name -SamAccountName $Name -Path $OU -AccountPassword $Password -Enabled $true
    Write-Host "Benutzer '$Name' wurde erstellt."
}

# --- 3. OU anlegen ---
function New-OU {
    $OUName = Read-Host "Name der neuen OU"
    New-ADOrganizationalUnit -Name $OUName
    Write-Host "OU '$OUName' erstellt."
}

# --- 4. Gruppe ---
function New-ADGroupSimple {
    $Group = Read-Host "Gruppenname"
    $OU = Read-Host "OU-Pfad (z. B. OU=IT,DC=firma,DC=local)"
    New-ADGroup -Name $Group -GroupScope Global -Path $OU
    Write-Host "Gruppe '$Group' erstellt."
}

# --- 5. Benutzer zu Gruppe ---
function Add-UserToGroup {
    $User = Read-Host "Benutzername"
    $Group = Read-Host "Gruppenname"
    Add-ADGroupMember -Identity $Group -Members $User
    Write-Host "Benutzer '$User' wurde zur Gruppe '$Group' hinzugefügt."
}

# --- 6. Benutzerimport aus Excel mit OU-Abfrage ---
function Import-UsersFromExcel {
    Write-Host "=== Benutzerimport aus Excel ===" -ForegroundColor Cyan

    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Host "Modul 'ImportExcel' wird installiert..." -ForegroundColor Yellow
        Install-Module -Name ImportExcel -Scope CurrentUser -Force
    }

    Import-Module ImportExcel

    $excelPath = Read-Host "Pfad zur Excel-Datei (z. B. C:\Import\Benutzer.xlsx)"
    $ouPath = Read-Host "In welcher OU sollen die Benutzer erstellt werden? (z. B. OU=Mitarbeiter,DC=firma,DC=local)"

    try { $users = Import-Excel -Path $excelPath }
    catch {
        Write-Host "Fehler beim Lesen der Excel-Datei: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    foreach ($u in $users) {
        $Name = "$($u.Vorname) $($u.Nachname)"
        $Sam  = $u.Benutzername
        $UPN  = "$Sam@firma.local"
        $Pass = ConvertTo-SecureString $u.Passwort -AsPlainText -Force

        try {
            New-ADUser `
                -Name $Name `
                -SamAccountName $Sam `
                -UserPrincipalName $UPN `
                -GivenName $u.Vorname `
                -Surname $u.Nachname `
                -Department $u.Abteilung `
                -Title $u.Position `
                -EmailAddress $u.'E-Mail' `
                -AccountPassword $Pass `
                -Enabled $true `
                -Path $ouPath

            Write-Host "Benutzer '$Name' erfolgreich erstellt." -ForegroundColor Green
        }
        catch {
            Write-Host "Fehler bei Benutzer '$Name': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "Vorgang abgeschlossen." -ForegroundColor Cyan
}

# --- 7. Feste IP (mit DHCP-Deaktivierung) ---
function Set-StaticIP {
    $Adapter = Read-Host "Netzwerkadaptername (z. B. Ethernet)"
    $IP = Read-Host "IP-Adresse"
    $Mask = Read-Host "Subnetzmaske (z. B. 255.255.255.0)"
    $GW = Read-Host "Gateway"
    $DNS = Read-Host "DNS-Server (durch Komma getrennt)"

    # Subnetzmaske → Präfixlänge
    $prefix = ($Mask -split '\.') | ForEach-Object {
        [Convert]::ToString([int]$_,2).PadLeft(8,'0')
    }
    $prefix = ($prefix -join '').ToCharArray() | Where-Object { $_ -eq '1' } | Measure-Object | Select-Object -ExpandProperty Count

    try {
        Write-Host "Deaktiviere DHCP auf Adapter '$Adapter'..." -ForegroundColor Yellow
        Set-NetIPInterface -InterfaceAlias $Adapter -Dhcp Disabled -ErrorAction Stop

        Get-NetIPAddress -InterfaceAlias $Adapter -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

        New-NetIPAddress -InterfaceAlias $Adapter -IPAddress $IP -PrefixLength $prefix -DefaultGateway $GW -ErrorAction Stop
        Set-DnsClientServerAddress -InterfaceAlias $Adapter -ServerAddresses ($DNS -split ",") -ErrorAction Stop

        Write-Host "Statische IP $IP/$prefix erfolgreich gesetzt." -ForegroundColor Green
        Write-Host "Gateway: $GW"
        Write-Host "DNS: $DNS"
    }
    catch {
        Write-Host "Fehler: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- 8. Lokaler Benutzer ---
function New-LocalUserSimple {
    $User = Read-Host "Lokaler Benutzername"
    $Password = Read-Host "Kennwort" -AsSecureString
    New-LocalUser -Name $User -Password $Password
    Write-Host "Lokaler Benutzer '$User' erstellt."
}

# --- Hauptmenü ---
do {
    Show-Menu
    $choice = Read-Host "Auswahl"
    switch ($choice) {
        1 { New-VM-GUI }
        2 { New-ADUserSimple }
        3 { New-OU }
        4 { New-ADGroupSimple }
        5 { Add-UserToGroup }
        6 { Import-UsersFromExcel }
        7 { Set-StaticIP }
        8 { New-LocalUserSimple }
        0 { break }
        default { Write-Host "Ungültige Eingabe." }
    }
    if ($choice -ne 0) {
        Write-Host ""
        Pause
    }
} while ($choice -ne 0)
