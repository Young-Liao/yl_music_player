#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>

#include "flutter_window.h"
#include "utils.h"

#include <thread>
#include <string>

// Global unique identifiers for YoungL Music Player
const wchar_t* kMutexName = L"Global\\YLMusicPlayer_SingleInstance_Mutex_837492";
const wchar_t* kPipeName = L"\\\\.\\pipe\\YLMusicPlayer_IPC_Pipe_837492";

// Helper to convert wchar_t string (UTF-16) to std::string (UTF-8)
std::string WideToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

// Forward CLI args to the running primary instance
void SendArgsToExistingInstance(int argc, wchar_t** argv) {
    HANDLE hPipe = CreateFile(
            kPipeName, GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (hPipe != INVALID_HANDLE_VALUE) {
        std::wstring args;
        for (int i = 1; i < argc; ++i) {
            if (i > 1) args += L"|"; // Use '|' delimiter for multiple paths
            args += argv[i];
        }

        std::string utf8Args = WideToUtf8(args);
        DWORD written;
        WriteFile(hPipe, utf8Args.c_str(), static_cast<DWORD>(utf8Args.size()), &written, NULL);
        CloseHandle(hPipe);
    }
}

int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
        _In_opt_ HINSTANCE hPrevInstance,
        _In_ PWSTR lpCmdLine,
        _In_ int nCmdShow) {

// 1. Enforce single instance via Mutex
HANDLE hMutex = CreateMutex(NULL, TRUE, kMutexName);
if (GetLastError() == ERROR_ALREADY_EXISTS) {
int argc;
wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
SendArgsToExistingInstance(argc, argv);
LocalFree(argv);
if (hMutex) CloseHandle(hMutex);
return 0; // Terminate secondary instance immediately
}

// 2. Cold Start Setup
if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
CreateAndAttachConsole();
}

::CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);

flutter::DartProject project(L"data");
std::vector<std::string> command_line_arguments = GetCommandLineArguments();
project.set_dart_entrypoint_arguments(command_line_arguments);

FlutterWindow window(project);
Win32Window::Point origin(10, 10);
Win32Window::Size size(1280, 720);
if (!window.Create(L"YL Music Player", origin, size)) {
if (hMutex) CloseHandle(hMutex);
return EXIT_FAILURE;
}
window.SetQuitOnClose(true);

::MSG msg;
while (::GetMessage(&msg, nullptr, 0, 0)) {
::TranslateMessage(&msg);
::DispatchMessage(&msg);
}

::CoUninitialize();
if (hMutex) CloseHandle(hMutex);
return EXIT_SUCCESS;
}
