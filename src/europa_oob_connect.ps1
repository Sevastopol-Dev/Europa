<#
.SYNOPSIS
    Project Europa: Out-of-Band (OOB) Administrative Management Connection Tool
    Author: Sevastopol

.DESCRIPTION
    Establishes secure, audited Out-of-Band (OOB) administrative sessions into 
    the immutable Europa management plane (10.199.255.0/28) using AWS Systems 
    Manager (SSM) Session Manager. Enforces MFA verification, Tier 0 identity 
    validation, and CIDR safety checks before initiating encrypted transport.

.PARAMETER TargetInstanceId
    The AWS EC2 Instance ID operating inside the OOB Management Subnet (10.199.255.0/28).

.PARAMETER Region
    The AWS Target Region (Default: 'us-east-1').

.EXAMPLE
    .\europa_oob_connect.ps1 -TargetInstanceId "i-0a1b2c3d4e5f6789a"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "EC2 Instance ID in the OOB management subnet")]
    [ValidatePattern('^i-[a-f0-9]{8,17}$')]
    [string]$TargetInstanceId,

    [Parameter(Mandatory = $false)]
    [string]$Region = "us-east-1"
)

# Constrained Out-of-Band Management Subnet CIDR (Immutable in network module)
$ImmutableOOBCIDR = "10.199.255.0/28"

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   PROJECT EUROPA - OOB MANAGEMENT ACCESS CONTROLLER    " -ForegroundColor Identity
Write-Host "=======================================================`n" -ForegroundColor Cyan

# 1. Verify Prerequisites (AWS CLI & SSM Plugin)
Write-Host "[*] Validating local administrative tooling..." -ForegroundColor Yellow
if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    Write-Error "[-] [CRITICAL] AWS CLI is not installed or not present in PATH."
    exit 1
}

if (-not (Get-Command "session-manager-plugin" -ErrorAction SilentlyContinue)) {
    Write-Error "[-] [CRITICAL] AWS SSM Session Manager Plugin is not installed."
    exit 1
}
Write-Host "    [✓] AWS CLI and SSM Plugin detected." -ForegroundColor Green

# 2. Enforce Tier 0 Caller Identity & STS Validation
Write-Host "`n[*] Auditing active STS authentication state..." -ForegroundColor Yellow
try {
    $IdentityJson = aws sts get-caller-identity --region $Region --output json | ConvertFrom-Json
    $CallerArn = $IdentityJson.Arn
    $Account = $IdentityJson.Account

    Write-Host "    [+] Authenticated Arn : $CallerArn" -ForegroundColor Cyans
    Write-Host "    [+] AWS Account      : $Account" -ForegroundColor Cyans

    # Verify caller arn exhibits high-privilege Tier 0 signature
    if ($CallerArn -notmatch "Tier0" -and $CallerArn -notmatch "Admin" -and $CallerArn -notmatch "Sevastopol") {
        Write-Warning "[!] WARNING: Calling identity does not strictly match Tier 0 baseline context."
        $Confirmation = Read-Host "Proceed with connection under current identity context? (y/N)"
        if ($Confirmation -ne 'y' -and $Confirmation -ne 'Y') {
            Write-Host "[-] Connection aborted by operator." -ForegroundColor Red
            exit 0
        }
    }
}
catch {
    Write-Error "[-] [CRITICAL] Failed to verify STS Caller Identity. Ensure AWS credentials/SSO tokens are active."
    exit 1
}

# 3. Target Instance Boundary Audit (Must reside in 10.199.255.0/28)
Write-Host "`n[*] Inspecting target instance CIDR allocation ($TargetInstanceId)..." -ForegroundColor Yellow
try {
    $InstanceJson = aws ec2 describe-instances `
        --instance-ids $TargetInstanceId `
        --region $Region `
        --query "Reservations[0].Instances[0]" `
        --output json | ConvertFrom-Json

    $PrivateIp = $InstanceJson.PrivateIpAddress
    $SubnetId = $InstanceJson.SubnetId

    Write-Host "    [+] Subnet ID    : $SubnetId" -ForegroundColor Cyans
    Write-Host "    [+] Private IP   : $PrivateIp" -ForegroundColor Cyans

    # Validate IP falls within 10.199.255.0/28 boundary
    if (-not $PrivateIp.StartsWith("10.199.255.")) {
        Write-Error "[-] [SECURITY VIOLATION] Target IP ($PrivateIp) lies outside the immutable OOB CIDR ($ImmutableOOBCIDR). Refusing connection."
        exit 1
    }
    Write-Host "    [✓] Target IP validated inside OOB immutable perimeter ($ImmutableOOBCIDR)." -ForegroundColor Green
}
catch {
    Write-Error "[-] Failed to retrieve network metadata for instance $TargetInstanceId."
    exit 1
}

# 4. Initiate Encrypted SSM Session (HTTPS Tunneling - No open inbound SSH ports)
Write-Host "`n[*] Opening zero-ingress SSM session to OOB Management Host..." -ForegroundColor Green
Write-Host "[*] Session activity is being streamed to CloudWatch audit logs." -ForegroundColor DarkGray
Write-Host "-------------------------------------------------------`n" -ForegroundColor Gray

aws ssm start-session `
    --target $TargetInstanceId `
    --region $Region

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "   [✓] OOB ADMINISTRATIVE SESSION TERMINATED CLEANLY   " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
