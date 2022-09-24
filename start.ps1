# Start script generated by ServerPackCreator 3.14.0.
# Depending on which modloader is set, different checks are run to ensure the server will start accordingly.
# If the modloader checks and setup are passed, Minecraft and EULA checks are run.
# If everything is in order, the server is started.

if ( (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "Warning! Running with administrator-privileges is not recommended."
}

Set-Location "$PSScriptRoot"

$MinecraftVersion = "1.19.2"
$ModLoader = "Fabric"
$ModLoaderVersion = "0.14.9"
$Args = ""
$Java = "java"
$LegacyFabricInstallerVersion = "0.10.1"
$FabricInstallerVersion = "0.11.1"
$QuiltInstallerVersion = "0.4.4"
$MinecraftServerUrl = "https://piston-data.mojang.com/v1/objects/f69c284232d7c7580bd89a5a4931c3581eae1378/server.jar"

# Variables with do_not_manually_edit are set automatically during script execution,
# so manually editing them will have no effect, as they will be overridden.
$MinecraftServerJarLocation = "do_not_manually_edit"
$LauncherJarLocation = "do_not_manually_edit"
$ServerRunCommand = "do_not_manually_edit"

Function DeleteFileSilently
{
    param ($FileToDelete)

    $ErrorActionPreference = "SilentlyContinue";
    if ((Get-Item "${FileToDelete}").PSIsContainer)
    {
        Remove-Item "${FileToDelete}" -Recurse
    }
    else
    {
        Remove-Item "${FileToDelete}"
    }
    $ErrorActionPreference = "Continue";
}

Function PauseScript
{
    Write-Host "Press any key to continue" -ForegroundColor Yellow
    $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
}

Function Crash
{
    Write-Host "Exiting..."
    PauseScript
    exit 1
}

Function global:RunJavaCommand
{
    param ($CommandToRun)

    CMD /C "`"${Java}`" ${CommandToRun}"
}

Function global:CheckJavaBitness
{
    $Bit = CMD /C "`"${Java}`" -version 2>&1"
    if ( ( ${Bit} | Select-String "32-Bit" ).Length -gt 0)
    {
        Write-Host "WARNING! 32-Bit Java detected! It is highly recommended to use a 64-Bit version of Java!"
    }
}

# $1 = Filename to check for
# $2 = Filename to save download as
# $3 = URL to download $2 from
# true if the File was successfully downloaded, false if it already exists
Function DownloadIfNotExists
{
    param ($FileToCheck, $FileToDownload, $DownloadURL)

    if (!(Test-Path -Path $FileToCheck -PathType Leaf))
    {

        Write-Host "${FileToCheck} could not be found."
        Write-Host "Downloading ${FileToDownload}"
        Write-Host "from ${DownloadURL}"

        Invoke-WebRequest -URI "${DownloadURL}" -OutFile "${FileToDownload}"

        if (Test-Path -Path "${FileToDownload}" -PathType Leaf)
        {
            Write-Host "Download complete."
            return $true
        }

    }
    else
    {
        Write-Host "${FileToCheck} present."
        return $false
    }

}

# If modloader = Forge, run Forge-specific checks
Function global:SetupForge
{
    ""
    "Running Forge checks and setup..."
    $ForgeInstallerUrl = "https://files.minecraftforge.net/maven/net/minecraftforge/forge/${MinecraftVersion}-${ModLoaderVersion}/forge-${MinecraftVersion}-${ModLoaderVersion}-installer.jar"
    $ForgeJarLocation = "do_not_manually_edit"
    $MINOR = ${MinecraftVersion}.Split(".")

    if ($MINOR[1] -le 16)
    {
        $ForgeJarLocation = "forge.jar"
        $script:LauncherJarLocation = "forge.jar"
        $script:MinecraftServerJarLocation = "minecraft_server.${MinecraftVersion}.jar"
        $script:ServerRunCommand = "-Dlog4j2.formatMsgNoLookups=true ${Args} -jar ${LauncherJarLocation} nogui"
    }
    else
    {
        $ForgeJarLocation = "libraries/net/minecraftforge/forge/${MinecraftVersion}-${ModLoaderVersion}/forge-${MinecraftVersion}-${ModLoaderVersion}-server.jar"
        $script:MinecraftServerJarLocation = "libraries/net/minecraft/server/${MinecraftVersion}/server-${MinecraftVersion}.jar"
        $script:ServerRunCommand = "-Dlog4j2.formatMsgNoLookups=true @user_jvm_args.txt @libraries/net/minecraftforge/forge/${MinecraftVersion}-${ModLoaderVersion}/win_args.txt nogui"

        if (!(Test-Path -Path 'user_jvm_args.txt' -PathType Leaf))
        {
            "# Xmx and Xms set the maximum and minimum RAM usage, respectively.`n" +
                    "# They can take any number, followed by an M or a G.`n" +
                    "# M means Megabyte, G means Gigabyte.`n" +
                    "# For example, to set the maximum to 3GB: -Xmx3G`n" +
                    "# To set the minimum to 2.5GB: -Xms2500M`n" +
                    "# A good default for a modded server is 4GB.`n" +
                    "# Uncomment the next line to set it.`n" +
                    "# -Xmx4G`n" +
                    "${script:Args}" | Out-File user_jvm_args.txt -encoding utf8
        }
        else
        {
            "user_jvm_args.txt present..."
        }
    }

    if ((DownloadIfNotExists "${ForgeJarLocation}" "forge-installer.jar" "${ForgeInstallerUrl}"))
    {
        "Forge Installer downloaded. Installing..."
        RunJavaCommand "-jar forge-installer.jar --installServer"

        if ($MINOR[1] -gt 16)
        {
            DeleteFileSilently  'run.bat'
            DeleteFileSilently  'run.sh'
        }
        else
        {
            "Renaming forge-${MinecraftVersion}-${ModLoaderVersion}.jar to forge.jar"
            Move-Item "forge-${MinecraftVersion}-${ModLoaderVersion}.jar" 'forge.jar'
        }

        if ((Test-Path -Path "${ForgeJarLocation}" -PathType Leaf))
        {
            DeleteFileSilently  'forge-installer.jar'
            DeleteFileSilently  'forge-installer.jar.log'
            "Installation complete. forge-installer.jar deleted."
        }
        else
        {
            DeleteFileSilently  'forge-installer.jar'
            "Something went wrong during the server installation. Please try again in a couple of minutes and check your internet connection."
            Crash
        }
    }
    ""
}

# If modloader = Fabric, run Fabric-specific checks
Function global:SetupFabric
{
    ""
    "Running Fabric checks and setup..."
    $FabricInstallerUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FabricInstallerVersion}/fabric-installer-${FabricInstallerVersion}.jar"
    $ImprovedFabricLauncherUrl = "https://meta.fabricmc.net/v2/versions/loader/${MinecraftVersion}/${ModLoaderVersion}/${FabricInstallerVersion}/server/jar"

    $ErrorActionPreference = "SilentlyContinue";
    $script:ImprovedFabricLauncherAvailable = [int][System.Net.WebRequest]::Create("${ImprovedFabricLauncherUrl}").GetResponse().StatusCode
    $ErrorActionPreference = "Continue";

    if ("${ImprovedFabricLauncherAvailable}" -eq "200")
    {
        "Improved Fabric Server Launcher available..."
        "The improved launcher will be used to run this Fabric server."
        $script:LauncherJarLocation = "fabric-server-launcher.jar"
        (DownloadIfNotExists "${script:LauncherJarLocation}" "${script:LauncherJarLocation}" "${ImprovedFabricLauncherUrl}") > $null
    }
    else
    {
        try
        {
            $ErrorActionPreference = "SilentlyContinue";
            $FabricAvailable = [int][System.Net.WebRequest]::Create("https://meta.fabricmc.net/v2/versions/loader/${MinecraftVersion}/${ModLoaderVersion}/server/json").GetResponse().StatusCode
            $ErrorActionPreference = "Continue";
        }
        catch
        {
            $FabricAvailable = "400"
        }
        if ("${FabricAvailable}" -ne "200")
        {
            "Fabric is not available for Minecraft ${MinecraftVersion}, Fabric ${ModLoaderVersion}."
            Crash
        }

        if ((DownloadIfNotExists "fabric-server-launch.jar" "fabric-installer.jar" "${FabricInstallerUrl}"))
        {
            "Installer downloaded..."
            $script:LauncherJarLocation = "fabric-server-launch.jar"
            $script:MinecraftServerJarLocation = "server.jar"
            RunJavaCommand "-jar fabric-installer.jar server -mcversion ${MinecraftVersion} -loader ${ModLoaderVersion} -downloadMinecraft"

            if ((Test-Path -Path 'fabric-server-launch.jar' -PathType Leaf))
            {
                DeleteFileSilently '.fabric-installer' -Recurse
                DeleteFileSilently 'fabric-installer.jar'
                "Installation complete. fabric-installer.jar deleted."
            }
            else
            {
                DeleteFileSilently  'fabric-installer.jar'
                "fabric-server-launch.jar not found. Maybe the Fabric servers are having trouble."
                "Please try again in a couple of minutes and check your internet connection."
                Crash
            }
        }
        else
        {
            "fabric-server-launch.jar present. Moving on..."
            $script:LauncherJarLocation = "fabric-server-launcher.jar"
            $script:MinecraftServerJarLocation = "server.jar"
        }
    }
    $script:ServerRunCommand = "-Dlog4j2.formatMsgNoLookups=true ${script:Args} -jar ${script:LauncherJarLocation} nogui"
    ""
}

# If modloader = Quilt, run Quilt-specific checks
Function global:SetupQuilt
{
    ""
    "Running Quilt checks and setup..."

    $QuiltInstallerUrl = "https://maven.quiltmc.org/repository/release/org/quiltmc/quilt-installer/${QuiltInstallerVersion}/quilt-installer-${QuiltInstallerVersion}.jar"

    if ((ConvertFrom-JSON (Invoke-WebRequest -Uri "https://meta.fabricmc.net/v2/versions/intermediary/${MinecraftVersion}")).Length -eq 0)
    {
        "Quilt is not available for Minecraft ${MinecraftVersion}, Quilt ${ModLoaderVersion}."
        Crash
    }
    elseif ((DownloadIfNotExists "quilt-server-launch.jar" "quilt-installer.jar" "${QuiltInstallerUrl}"))
    {
        "Installer downloaded. Installing..."
        RunJavaCommand "-jar quilt-installer.jar install server ${MinecraftVersion} --download-server --install-dir=."

        if ((Test-Path -Path 'quilt-server-launch.jar' -PathType Leaf))
        {
            DeleteFileSilently 'quilt-installer.jar'
            "Installation complete. quilt-installer.jar deleted."
        }
        else
        {
            DeleteFileSilently 'quilt-installer.jar'
            "quilt-server-launch.jar not found. Maybe the Quilt servers are having trouble."
            "Please try again in a couple of minutes and check your internet connection."
            Crash
        }

    }
    else
    {
        "quilt-server-launch.jar present. Moving on..."
    }
    $script:LauncherJarLocation = "quilt-server-launch.jar"
    $script:MinecraftServerJarLocation = "server.jar"
    $script:ServerRunCommand = "-Dlog4j2.formatMsgNoLookups=true ${Args} -jar ${LauncherJarLocation} nogui"
    ""
}

# If modloader = LegacyFabric, run LegacyFabric-specific checks
Function global:SetupLegacyFabric
{
    ""
    "Running LegacyFabric checks and setup..."

    $LegacyFabricInstallerUrl = "https://maven.legacyfabric.net/net/legacyfabric/fabric-installer/${LegacyFabricInstallerVersion}/fabric-installer-${LegacyFabricInstallerVersion}.jar"

    if ((ConvertFrom-JSON (Invoke-WebRequest -Uri "https://meta.legacyfabric.net/v2/versions/loader/${MinecraftVersion}")).Length -eq 0)
    {
        "LegacyFabric is not available for Minecraft ${MinecraftVersion}, LegacyFabric ${ModLoaderVersion}."
        Crash
    }
    elseif ((DownloadIfNotExists "fabric-server-launch.jar" "legacyfabric-installer.jar" "${LegacyFabricInstallerUrl}"))
    {
        "Installer downloaded. Installing..."
        RunJavaCommand "-jar legacyfabric-installer.jar server -mcversion ${MinecraftVersion} -loader ${ModLoaderVersion} -downloadMinecraft"

        if ((Test-Path -Path 'fabric-server-launch.jar' -PathType Leaf))
        {
            DeleteFileSilently 'legacyfabric-installer.jar'
            "Installation complete. legacyfabric-installer.jar deleted."
        }
        else
        {
            DeleteFileSilently 'legacyfabric-installer.jar'
            "fabric-server-launch.jar not found. Maybe the LegacyFabric servers are having trouble."
            "Please try again in a couple of minutes and check your internet connection."
            Crash
        }

    }
    else
    {
        "fabric-server-launch.jar present. Moving on..."
    }
    $script:LauncherJarLocation = "fabric-server-launch.jar"
    $script:MinecraftServerJarLocation = "server.jar"
    $script:ServerRunCommand = "-Dlog4j2.formatMsgNoLookups=true ${Args} -jar ${LauncherJarLocation} nogui"
    ""
}

# Check for a minecraft server and download it if necessary
Function global:Minecraft
{
    ""
    if (($ModLoader -eq "Fabric") -and (${ImprovedFabricLauncherAvailable} -eq "200"))
    {
        "Skipping Minecraft Server JAR checks because we are using the improved Fabric Server Launcher."
    }
    else
    {
        (DownloadIfNotExists "${MinecraftServerJarLocation}" "${MinecraftServerJarLocation}" "${MinecraftServerUrl}") > $null
    }
    ""
}

# Check for eula.txt and generate if necessary
Function Eula
{
    ""
    if (!(Test-Path -Path 'eula.txt' -PathType Leaf))
    {
        "Mojang's EULA has not yet been accepted. In order to run a Minecraft server, you must accept Mojang's EULA."
        "Mojang's EULA is available to read at https://aka.ms/MinecraftEULA"
        "If you agree to Mojang's EULA then type 'I agree'"
        $Answer = Read-Host -Prompt 'Answer: '

        if (${Answer} -eq "I agree")
        {
            "User agreed to Mojang's EULA."

            "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://aka.ms/MinecraftEULA).`n" +
                    "eula=true" | Out-File eula.txt -encoding utf8
        }
        else
        {
            "User did not agree to Mojang's EULA."
            "Entered: ${Answer}"
            "You can not run a Minecraft server unless you agree to Mojang#s EULA."
            Crash
        }
    }
    else
    {
        "eula.txt present. Moving on..."
    }
    ""
}

if ( ${PSScriptRoot}.Contains(" "))
{
    "WARNING! The current location of this script contains spaces. This may cause this server to crash!"
    "It is strongly recommended to move this server pack to a location whose path does NOT contain SPACES!"
    ""
    "Current path:"
    "${PSScriptRoot}"
    ""

    $WhyMustPowerShellBeThisWayLikeSeriouslyWhatTheFrag = Read-Host -Prompt 'Are you sure you want to continue? (Yes/No): '

    if (${WhyMustPowerShellBeThisWayLikeSeriouslyWhatTheFrag} -eq "Yes")
    {
        "Alrighty. Prepare for unforseen consequences, Mr. Freeman..."
    }
    else
    {
        Crash
    }
}

# Main
switch ( ${ModLoader} )
{
    Forge
    {
        SetupForge
    }
    Fabric
    {
        SetupFabric
    }
    Quilt
    {
        SetupQuilt
    }
    LegacyFabric
    {
        SetupLegacyFabric
    }
    default
    {
        "Incorrect modloader specified: ${ModLoader}"
        Crash
    }
}

CheckJavaBitness
Minecraft
Eula

""
"Starting server..."
""
"Minecraft version: ${MinecraftVersion}"
"Modloader:         ${ModLoader}"
"Modloader version: ${ModLoaderVersion}"
if (!("${LauncherJarLocation}" -eq "do_not_manually_edit"))
{
    "Launcher JAR:      ${LauncherJarLocation}"
}
""
"Java args:         ${Args}"
"Java path:         ${Java}"
"Run Command:       ${Java} ${ServerRunCommand}"
"Java version:"
RunJavaCommand "-version"
""

RunJavaCommand "${ServerRunCommand}"

""
"Exiting..."
PauseScript
exit 0
