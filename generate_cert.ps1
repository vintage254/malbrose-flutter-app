# PowerShell script to generate a self-signed certificate for HTTPS
# Make sure OpenSSL is installed and in your PATH before running this script

# Set the certificate details
$certSubject = "/CN=malbrose.local/O=Malbrose POS/OU=IT Department/C=US"
$certPath = "certificates"
$certFile = "$certPath/server.crt"
$keyFile = "$certPath/server.key"
$validDays = 365

# Create directory if it doesn't exist
if (-not (Test-Path $certPath)) {
    New-Item -ItemType Directory -Path $certPath -Force | Out-Null
    Write-Host "Created directory: $certPath"
}

# Remove existing files if they exist
if (Test-Path $certFile) {
    Remove-Item $certFile -Force
    Write-Host "Removed existing certificate: $certFile"
}

if (Test-Path $keyFile) {
    Remove-Item $keyFile -Force
    Write-Host "Removed existing key: $keyFile"
}

# Generate self-signed certificate
Write-Host "Generating self-signed certificate..."

# Check if OpenSSL is installed
try {
    $openSSLVersion = openssl version
    Write-Host "Using $openSSLVersion"
} catch {
    Write-Host "Error: OpenSSL is not installed or not in your PATH" -ForegroundColor Red
    Write-Host "Please install OpenSSL and try again." -ForegroundColor Red
    exit 1
}

# Generate a key and certificate
openssl req -x509 -newkey rsa:4096 -nodes -keyout $keyFile -out $certFile -days $validDays -subj $certSubject
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error generating certificate" -ForegroundColor Red
    exit 1
}

Write-Host "Certificate generated successfully!" -ForegroundColor Green
Write-Host "Certificate: $certFile"
Write-Host "Private Key: $keyFile"
Write-Host "Valid for $validDays days"

# Generate certificate info
openssl x509 -in $certFile -text -noout | Select-Object -First 15
Write-Host "..."

# Instructions for importing the certificate
Write-Host "`nTo use this certificate:" -ForegroundColor Cyan
Write-Host "1. Copy $certFile and $keyFile to your application's certificate directory."
Write-Host "2. Update your Dart/Flutter app to use these certificate files."
Write-Host "3. For trusted connections, import $certFile to your client's trusted certificate store." 