#pragma once

#include <windows.h>
#include <string>
#include <vector>
#include <iostream>

class DllLoader {
public:
    // Initialize the DLL loader with the application directory
    static void Initialize() {
        char buffer[MAX_PATH];
        GetModuleFileNameA(NULL, buffer, MAX_PATH);
        std::string exePath(buffer);
        size_t lastSlash = exePath.find_last_of('\\');
        if (lastSlash != std::string::npos) {
            appDirectory = exePath.substr(0, lastSlash + 1);
        }
        
        // Add the application directory to the DLL search path
        SetDllDirectoryA(appDirectory.c_str());
        
        // Add the ucrt subdirectory to the search path if it exists
        std::string ucrtPath = appDirectory + "ucrt";
        if (DirectoryExists(ucrtPath)) {
            searchPaths.push_back(ucrtPath);
        }
        
        // Register the DLL load handler
        SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS | LOAD_LIBRARY_SEARCH_USER_DIRS);
        
        // Convert string to wide string for AddDllDirectory
        wchar_t wAppDir[MAX_PATH];
        MultiByteToWideChar(CP_ACP, 0, appDirectory.c_str(), -1, wAppDir, MAX_PATH);
        AddDllDirectory(wAppDir);
    }
    
    // Try to load a DLL from our search paths
    static HMODULE LoadDll(const std::string& dllName) {
        // First try the default search path
        HMODULE hModule = LoadLibraryA(dllName.c_str());
        if (hModule) return hModule;
        
        // Try each of our custom search paths
        for (const auto& path : searchPaths) {
            std::string fullPath = path + "\\" + dllName;
            hModule = LoadLibraryA(fullPath.c_str());
            if (hModule) return hModule;
        }
        
        // If we get here, we couldn't find the DLL
        std::cerr << "Failed to load DLL: " << dllName << std::endl;
        return NULL;
    }
    
private:
    static std::string appDirectory;
    static std::vector<std::string> searchPaths;
    
    static bool DirectoryExists(const std::string& path) {
        DWORD attrib = GetFileAttributesA(path.c_str());
        return (attrib != INVALID_FILE_ATTRIBUTES && 
               (attrib & FILE_ATTRIBUTE_DIRECTORY));
    }
};

// Initialize static members
std::string DllLoader::appDirectory = "";
std::vector<std::string> DllLoader::searchPaths = {};
