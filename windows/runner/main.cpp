#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#include <thread>
#include <iostream>
#include <memory>
#include <string>

const wchar_t* kMutexName = L"Global\\YLMusicPlayer_Mutex_837492";
const wchar_t* kPipeName = L"\\\\.\\pipe\\YLMusicPlayer_Pipe_837492";

void SendArgsToExistingInstance(int argc, wchar_t** argv) {
    HANDLE hPipe = CreateFile(
            kPipeName, GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (hPipe != INVALID_HANDLE_VALUE) {
        std::wstring args;
        for (int i = 1; i < argc; ++i) {
            if (i > 1) args += L" ";
            args += argv[i];
        }
        DWORD written;
        DWORD bytesToWrite = static_cast<DWORD>((args.size() + 1) * sizeof(wchar_t));
        WriteFile(hPipe, args.c_str(), bytesToWrite, &written, NULL);
        CloseHandle(hPipe);
    }
}

std::string Utf16ToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

void StartPipeServer(HWND hwnd) {
    std::thread([hwnd]() {
        while (true) {
            HANDLE hPipe = CreateNamedPipe(
                    kPipeName,
                    PIPE_ACCESS_INBOUND,
                    PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
                    1, 0, 0, 0, NULL);

            if (hPipe == INVALID_HANDLE_VALUE) break;

            if (ConnectNamedPipe(hPipe, NULL) || GetLastError() == ERROR_PIPE_CONNECTED) {
                wchar_t buffer[1024] = {0};
                DWORD bytesRead = 0;
                if (ReadFile(hPipe, buffer, sizeof(buffer) - sizeof(wchar_t), &bytesRead, NULL)) {
                    std::wstring wargs(buffer);
                    std::string utf8_args = Utf16ToUtf8(wargs);

                    if (IsIconic(hwnd)) {
                        ShowWindow(hwnd, SW_RESTORE);
                    }
                    SetForegroundWindow(hwnd);

                    // 触发全局通道转发
                    if (g_method_channel != nullptr && !utf8_args.empty()) {
                        g_method_channel->InvokeMethod(
                                "onNewArgs",
                                std::make_unique<flutter::EncodableValue>(utf8_args));
                    }
                }
            }
            CloseHandle(hPipe);
        }
    }).detach();
}

int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
        _In_opt_ HINSTANCE hPrevInstance,
        _In_ PWSTR lpCmdLine,
        _In_ int nCmdShow) {

HANDLE hMutex = CreateMutex(NULL, TRUE, kMutexName);
if (GetLastError() == ERROR_ALREADY_EXISTS) {
int argc;
wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
SendArgsToExistingInstance(argc, argv);
LocalFree(argv);
if (hMutex) CloseHandle(hMutex);
return 0;
}

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

// 启动管道，此时 window.Create() 已成功触发 OnCreate 并创建了 g_method_channel
StartPipeServer(window.GetHandle());

::MSG msg;
while (::GetMessage(&msg, nullptr, 0, 0)) {
::TranslateMessage(&msg);
::DispatchMessage(&msg);
}

::CoUninitialize();
if (hMutex) CloseHandle(hMutex);
return EXIT_SUCCESS;
}