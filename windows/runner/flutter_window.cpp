#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "flutter/standard_method_codec.h"
#include "flutter/method_channel.h"
#include "flutter/encodable_value.h"

// Add Windows API headers for DPAPI
#include <wincrypt.h>
#pragma comment(lib, "crypt32.lib")
#include <string>
#include <iostream>
#include <sstream>
#include <fstream>
#include <Windows.h>
// Add Windows Credential Manager headers
#include <wincred.h>
#pragma comment(lib, "credui.lib")
#pragma comment(lib, "advapi32.lib")
// Add ShlObj.h for SHGetFolderPathW and CSIDL constants
#include <ShlObj.h>
// Add vector for std::vector
#include <vector>

// Helper function to get app data file path
std::wstring GetAppDataFilePath() {
  wchar_t path[MAX_PATH];
  if (SUCCEEDED(SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, path))) {
    std::wstring filePath(path);
    filePath += L"\\MalbrosePOS\\secure_storage.bin";
    
    // Create directory if it doesn't exist
    std::wstring dirPath(path);
    dirPath += L"\\MalbrosePOS";
    CreateDirectoryW(dirPath.c_str(), NULL);
    
    return filePath;
  }
  return L"";
}

// Helper function to convert UTF-8 string to wide string
std::wstring Utf8ToWide(const std::string& utf8Str) {
  if (utf8Str.empty()) {
    return std::wstring();
  }
  
  // Get required buffer size
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, nullptr, 0);
  if (size == 0) {
    return std::wstring();
  }
  
  // Convert to wide string
  std::vector<wchar_t> buffer(size);
  MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, buffer.data(), size);
  
  return std::wstring(buffer.data());
}

// Helper function to convert wide string to UTF-8 string
std::string WideToUtf8(const std::wstring& wideStr) {
  if (wideStr.empty()) {
    return std::string();
  }
  
  // Get required buffer size
  int size = WideCharToMultiByte(CP_UTF8, 0, wideStr.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (size == 0) {
    return std::string();
  }
  
  // Convert to UTF-8
  std::vector<char> buffer(size);
  WideCharToMultiByte(CP_UTF8, 0, wideStr.c_str(), -1, buffer.data(), size, nullptr, nullptr);
  
  return std::string(buffer.data());
}

// Store a credential in Windows Credential Manager
bool StoreCredential(const std::string& key, const std::string& value, const std::string& description) {
  std::wstring wKey = Utf8ToWide(key);
  std::wstring wValue = Utf8ToWide(value);
  std::wstring wDesc = Utf8ToWide(description);
  
  CREDENTIALW cred = {0};
  cred.Type = CRED_TYPE_GENERIC;
  cred.TargetName = const_cast<LPWSTR>(wKey.c_str());
  cred.CredentialBlobSize = static_cast<DWORD>(value.length());
  cred.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char*>(value.c_str()));
  cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
  cred.UserName = const_cast<LPWSTR>(L"MalbrosePOS");
  
  if (wDesc.length() > 0) {
    cred.Comment = const_cast<LPWSTR>(wDesc.c_str());
  }
  
  return CredWriteW(&cred, 0) == TRUE;
}

// Retrieve a credential from Windows Credential Manager
std::string GetCredential(const std::string& key) {
  std::wstring wKey = Utf8ToWide(key);
  PCREDENTIALW pCred = nullptr;
  
  if (CredReadW(wKey.c_str(), CRED_TYPE_GENERIC, 0, &pCred)) {
    if (pCred->CredentialBlobSize > 0) {
      std::string value(reinterpret_cast<char*>(pCred->CredentialBlob), pCred->CredentialBlobSize);
      CredFree(pCred);
      return value;
    }
    CredFree(pCred);
  }
  
  return "";
}

// Delete a credential from Windows Credential Manager
bool DeleteCredential(const std::string& key) {
  std::wstring wKey = Utf8ToWide(key);
  return CredDeleteW(wKey.c_str(), CRED_TYPE_GENERIC, 0) == TRUE;
}

// Helper function to encrypt data using DPAPI
std::vector<BYTE> EncryptWithDPAPI(const std::string& data) {
  std::vector<BYTE> encrypted;
  DATA_BLOB dataIn = {0};
  DATA_BLOB dataOut = {0};
  
  dataIn.pbData = (BYTE*)data.c_str();
  dataIn.cbData = static_cast<DWORD>(data.length());
  
  if (CryptProtectData(&dataIn, L"MalbrosePOS_EncryptionKey", nullptr, nullptr, nullptr, 0, &dataOut)) {
    encrypted.resize(dataOut.cbData);
    memcpy(encrypted.data(), dataOut.pbData, dataOut.cbData);
    LocalFree(dataOut.pbData);
  }
  
  return encrypted;
}

// Helper function to decrypt data using DPAPI
std::string DecryptWithDPAPI(const std::vector<BYTE>& data) {
  std::string decrypted;
  DATA_BLOB dataIn = {0};
  DATA_BLOB dataOut = {0};
  
  dataIn.pbData = const_cast<BYTE*>(data.data());
  dataIn.cbData = static_cast<DWORD>(data.size());
  
  if (CryptUnprotectData(&dataIn, nullptr, nullptr, nullptr, nullptr, 0, &dataOut)) {
    decrypted = std::string(reinterpret_cast<char*>(dataOut.pbData), dataOut.cbData);
    LocalFree(dataOut.pbData);
  }
  
  return decrypted;
}

// Save data to file
bool SaveEncryptedData(const std::string& data) {
  auto encrypted = EncryptWithDPAPI(data);
  if (encrypted.empty()) {
    return false;
  }
  
  std::wstring filePath = GetAppDataFilePath();
  if (filePath.empty()) {
    return false;
  }
  
  std::ofstream file(filePath, std::ios::binary);
  if (!file) {
    return false;
  }
  
  file.write(reinterpret_cast<const char*>(encrypted.data()), encrypted.size());
  return !file.fail();
}

// Load data from file
std::string LoadEncryptedData() {
  std::wstring filePath = GetAppDataFilePath();
  if (filePath.empty()) {
    return "";
  }
  
  std::ifstream file(filePath, std::ios::binary | std::ios::ate);
  if (!file) {
    return "";
  }
  
  std::streamsize size = file.tellg();
  file.seekg(0, std::ios::beg);
  
  std::vector<BYTE> buffer(size);
  if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
    return "";
  }
  
  return DecryptWithDPAPI(buffer);
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  
  // Set up method channel for secure storage operations
  flutter::MethodChannel<> channel(
    flutter_controller_->engine()->messenger(),
    "com.malbrose.pos/secure_storage",
    &flutter::StandardMethodCodec::GetInstance()
  );
  
  channel.SetMethodCallHandler(
    [](const flutter::MethodCall<>& call, std::unique_ptr<flutter::MethodResult<>> result) {
      if (call.method_name() == "getEncryptionKey") {
        // Retrieve the encryption key using DPAPI
        std::string key = LoadEncryptedData();
        if (!key.empty()) {
          result->Success(key);
        } else {
          result->Error("NOT_FOUND", "Encryption key not found");
        }
      } else if (call.method_name() == "setEncryptionKey") {
        // Store the encryption key using DPAPI
        const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments) {
          auto keyIt = arguments->find(flutter::EncodableValue("key"));
          if (keyIt != arguments->end() && std::holds_alternative<std::string>(keyIt->second)) {
            std::string key = std::get<std::string>(keyIt->second);
            if (SaveEncryptedData(key)) {
              result->Success();
            } else {
              result->Error("SAVE_FAILED", "Failed to save encryption key");
            }
          } else {
            result->Error("INVALID_ARGUMENTS", "Key parameter not found or not a string");
          }
        } else {
          result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
        }
      } 
      // Windows Credential Manager methods
      else if (call.method_name() == "setCredential") {
        // Store a credential in Windows Credential Manager
        const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments) {
          auto keyIt = arguments->find(flutter::EncodableValue("key"));
          auto valueIt = arguments->find(flutter::EncodableValue("value"));
          auto descIt = arguments->find(flutter::EncodableValue("description"));
          
          if (keyIt != arguments->end() && valueIt != arguments->end() && 
              std::holds_alternative<std::string>(keyIt->second) && 
              std::holds_alternative<std::string>(valueIt->second)) {
            
            std::string key = std::get<std::string>(keyIt->second);
            std::string value = std::get<std::string>(valueIt->second);
            std::string description = "";
            
            if (descIt != arguments->end() && std::holds_alternative<std::string>(descIt->second)) {
              description = std::get<std::string>(descIt->second);
            }
            
            if (StoreCredential(key, value, description)) {
              result->Success();
            } else {
              result->Error("CRED_SAVE_FAILED", "Failed to save credential");
            }
          } else {
            result->Error("INVALID_ARGUMENTS", "Required parameters not found or not strings");
          }
        } else {
          result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
        }
      } else if (call.method_name() == "getCredential") {
        // Retrieve a credential from Windows Credential Manager
        const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments) {
          auto keyIt = arguments->find(flutter::EncodableValue("key"));
          if (keyIt != arguments->end() && std::holds_alternative<std::string>(keyIt->second)) {
            std::string key = std::get<std::string>(keyIt->second);
            std::string value = GetCredential(key);
            
            if (!value.empty()) {
              result->Success(value);
            } else {
              result->Error("NOT_FOUND", "Credential not found");
            }
          } else {
            result->Error("INVALID_ARGUMENTS", "Key parameter not found or not a string");
          }
        } else {
          result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
        }
      } else if (call.method_name() == "deleteCredential") {
        // Delete a credential from Windows Credential Manager
        const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments) {
          auto keyIt = arguments->find(flutter::EncodableValue("key"));
          if (keyIt != arguments->end() && std::holds_alternative<std::string>(keyIt->second)) {
            std::string key = std::get<std::string>(keyIt->second);
            
            if (DeleteCredential(key)) {
              result->Success();
            } else {
              result->Error("DELETE_FAILED", "Failed to delete credential");
            }
          } else {
            result->Error("INVALID_ARGUMENTS", "Key parameter not found or not a string");
          }
        } else {
          result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
        }
      } else {
        result->NotImplemented();
      }
    }
  );

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. Ensure a frame is pending to ensure the window is shown.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
