# Imports the UniversalDashboard module
# If you don't have this already you will need to download it; for Powershell version 5 you can do 'Install-Module UniversalDashboard'
Import-Module UniversalDashboard

# Create a new Universal Dashboard Authentication method, this one will be for our Azure AD Instance
# Client ID = The Azure application ID
# Doamin = your Azure AD Domain
# Teneant ID = Your Azure AD Tenant
$AuthenticationMethod_Azure = New-UDAuthenticationMethod -ClientId '00000000-0000-0000-0000-000000000000' `
                        -Instance https://login.microsoftonline.com `
                        -Domain yourdomain.onmicrosoft.com `
                        -TenantId '0000000-0000-0000-0000-000000000000'

# This creates a new authorization policy checking if the current user has the group "PD-UD-View"
# Whenever we check if the user has a group etc. we MUST use the Groups Object ID instead of it's name.
$AP_PSUDGuest = New-UDAuthorizationPolicy -Name "Policy_PS-UD-View" -Endpoint {
            param($User)
            $User.HasClaim("groups", "688d41fb-a598-4772-801a-87398c1314e8")
        }
# This creates a new authorization policy checking if the current user has the group "PD-UD-Admin"
$AP_PSUDAdmin = New-UDAuthorizationPolicy -Name "Policy_PS-UD-Admin" -Endpoint {
            param($User)
            $User.HasClaim("groups", "22720538-b44e-4a7c-af3e-60cc4410ab80")
        }
        
# Creates a new Login page using our Azure ad Authentication method. 
# We must also pass ALL of our Authorization Policies as this will inistialize them and allow us to use them
# later in the program
$LoginPage = New-UDLoginPage -AuthenticationMethod $AuthenticationMethod_Azure -AuthorizationPolicy @($AP_PSUDAdmin, $AP_PSUDGuest)

# Creates a new Web page, and applies our PS-UD-View policy, this means only people with the PS-UD-View group
# may see and interact with this page.
$Page_Home = New-UDPage -Name "Home" -Icon home -Endpoint {
        # Creates a new UD Card with some text.
        New-UDCard -Text "Welcome $User"
    } -DefaultHomePage -AuthorizationPolicy "Policy_PS-UD-View"

# Creates a new page, but this time only people with the group PS-UD-Admin can view and 
# interact with the webpage.
$Page_Settings = New-UDPage -Name "Settings" -Icon Cogs -Endpoint {
        # Ceates a new UD Card letting the user know they are in the admin area,
        New-UDCard -Text "Admin area"

        # Createss a new ud card but this time we add an Endpoint,
        # this means whenever this element is loaded it will run
        # whatever code is in the -endpoint.
        New-UDCard -Title "Server CPU Information" -Endpoint {
            
            # Gets and stores CPU Information
            # My server has 1 Xeon processor, so this approach is fine.
            $CPU = @(Get-WmiObject -Class Win32_Processor)[0]

            # Create a new heading element showing the current CPU Load percentage
            New-UDHeading -Text "CPU Utilisation: $($CPU.LoadPercentage) %"

            # Creates a new Chart showing the top 5 running processors on the host server.
            New-UDChart -Title "CPU Processes" -Endpoint {
                Get-Process | Sort-Object -Property WorkingSet -Descending | Select-Object -First 5 | Out-UDChartData -DataProperty WorkingSet -LabelProperty "Name"
            }
        } 
    } -AuthorizationPolicy "Policy_PS-UD-Admin" -AutoRefresh -RefreshInterval 10

# Creates a new Dashboard using the above created pages.
$dashboard = New-UDDashboard -Title "Test" -LoginPage $LoginPage -Pages @(
    $Page_Home
    $Page_Settings
) 

# To Allow for HTTPS data tranfer for our webpage we must have a valid license, this is where i store mine. 
$Cert = (Get-ChildItem -Path  Cert:\CurrentUser\My\4CA726813CC4A8B4850E773DE5270502DB9E756F)

# Starts the UD Dashboard instance on port 443 using our HTTPS Certificate.
# For testing you can remove the -Certificate paramter and use -AllowHttpForLogin
# Making the website accible via http:// instead of https://
Start-UDDashboard -Dashboard $Dashboard -Port 443 -Certificate $Cert -Name "UD-PS-Dash01" 
